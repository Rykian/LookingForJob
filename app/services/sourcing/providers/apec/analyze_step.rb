# frozen_string_literal: true

require "date"
require "json"
require "nokogiri"

module Sourcing
  module Providers
    module Apec
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 1

        CONTRACT_PATTERNS = [
          [/\bCDI\b/i,                                        "PERMANENT"],
          [/\bCDD\b/i,                                        "FIXED_TERM"],
          [/alternance|apprentissage|professionnalisation/i, "APPRENTICESHIP"],
          [/\bstage\b/i,                                     "INTERNSHIP"],
          [/freelance|ind[ée]pendant/i,                      "FREELANCE"],
          [/int[ée]rim|temporaire/i,                         "TEMPORARY"],
          [/temps plein|full[-_ ]?time/i,                   "FULL_TIME"],
          [/temps partiel|part[-_ ]?time/i,                 "PART_TIME"],
        ].freeze

        LOCATION_MODE_PATTERNS = [
          [/total possible|t[ée]l[ée]travail permanent|full[-_ ]?remote|100\s*%/i, "remote"],
          [/partiel possible|ponctuel autoris[ée]|hybride|2-3j|2 jours|3 jours/i,    "hybrid"],
          [/pr[ée]sentiel|sur site|on[-_ ]?site/i,                                    "on-site"],
        ].freeze

        DATE_PATTERN = /(\d{2})\/(\d{2})\/(\d{4})/

        def call(input)
          html = input[:html_content] || input[:html] || ""
          doc = Nokogiri::HTML(html)
          ld = extract_json_ld_job_posting(doc)
          top_metadata = extract_top_metadata(doc)
          detail_values = extract_detail_values(doc)
          salary_source = ld["baseSalary"] || detail_values["Salaire"]

          {
            title: normalize_text(ld["title"] || text_at(doc, "h1")),
            company: normalize_text(ld.dig("hiringOrganization", "name") || top_metadata[:company]),
            city: parse_city(ld.dig("jobLocation", "address", "addressLocality") || top_metadata[:city]),
            employment_type: normalize_contract(ld["employmentType"] || top_metadata[:employment_type]),
            salary_min_minor: parse_salary_min(salary_source),
            salary_max_minor: parse_salary_max(salary_source),
            salary_currency: parse_salary_currency(salary_source),
            location_mode: detect_location_mode(detail_values["Télétravail"], doc.text),
            posted_at: parse_posted_at(ld["datePosted"] || top_metadata[:posted_at]),
            description_html: extract_description_html(doc, ld),
          }
        end

        private

        def extract_top_metadata(doc)
          {
            company: text_at(doc, "apec-offre-metadata .details-offer-list li:first-child"),
            employment_type: text_at(doc, "apec-offre-metadata .details-offer-list li:nth-child(2) span") ||
              text_at(doc, "apec-offre-metadata .details-offer-list li:nth-child(2)"),
            city: text_at(doc, "apec-offre-metadata .details-offer-list li:nth-child(3)"),
            posted_at: text_at(doc, "apec-offre-metadata .date-offre"),
          }
        end

        def extract_detail_values(doc)
          doc.css(".details-post").each_with_object({}) do |node, values|
            label = normalize_text(node.at_css("h4")&.text)
            next if label.nil?

            direct_text = node.element_children
              .reject { |child| child.name == "h4" }
              .map(&:text)
              .join(" ")
            value = normalize_text(direct_text)
            values[label] = value
          end
        end

        def normalize_contract(raw)
          value = normalize_text(raw)
          return nil if value.nil?

          CONTRACT_PATTERNS.each do |pattern, normalized|
            return normalized if value.match?(pattern)
          end

          nil
        end

        def parse_city(raw)
          text = normalize_text(raw)
          return nil if text.nil?

          text.sub(/\s*-\s*\d{2,3}\z/, "").strip.presence
        end

        def parse_salary_min(raw)
          return parse_salary_hash(raw, key: "minValue") if raw.is_a?(Hash)

          amounts = extract_salary_amounts(raw)
          amounts[0]
        end

        def parse_salary_max(raw)
          return parse_salary_hash(raw, key: "maxValue") if raw.is_a?(Hash)

          amounts = extract_salary_amounts(raw)
          amounts[1]
        end

        def parse_salary_currency(raw)
          if raw.is_a?(Hash)
            return normalize_text(raw["currency"]).to_s.upcase.presence
          end

          text = normalize_text(raw)
          return nil if text.nil?
          return "EUR" if text.match?(/€|eur/i)
          return "USD" if text.match?(/\$/)
          return "GBP" if text.match?(/£|gbp/i)

          nil
        end

        def extract_salary_amounts(raw)
          text = normalize_text(raw)
          return [nil, nil] if text.nil? || text.match?(/n[ée]gocier/i)

          values = text.scan(/\d+(?:[.,]\d+)?/).map { |value| normalize_salary_number(value, text) }
          return [nil, nil] if values.empty?

          [values[0], values[1]]
        end

        def normalize_salary_number(raw, source_text)
          number = raw.to_s.tr(",", ".").to_f
          return nil unless number.positive?

          yearly = if source_text.match?(/k\s*€|k€|\bk\b/i) && number < 1_000
            number * 1_000
          else
            number
          end

          yearly.to_i
        end

        def parse_salary_hash(raw, key:)
          amount = raw.dig("value", key).to_f
          return nil unless amount.positive?

          unit_text = normalize_text(raw.dig("value", "unitText")).to_s.upcase
          yearly = unit_text == "MONTH" ? amount * 12 : amount
          yearly.to_i
        end

        def detect_location_mode(telework_text, page_text)
          [telework_text, normalize_text(page_text)].compact.each do |raw_text|
            LOCATION_MODE_PATTERNS.each do |pattern, mode|
              return mode if raw_text.match?(pattern)
            end
          end

          nil
        end

        def parse_posted_at(raw)
          text = normalize_text(raw)
          return nil if text.nil?

          match = text.match(DATE_PATTERN)
          return nil unless match

          Date.strptime(match[0], "%d/%m/%Y").iso8601
        rescue Date::Error
          nil
        end

        def extract_description_html(doc, ld)
          node = doc.css(".details-post").find do |candidate|
            normalize_text(candidate.at_css("h4")&.text) == "Descriptif du poste"
          end

          if node
            fragment = Nokogiri::HTML.fragment("")
            node.element_children.each do |child|
              label = normalize_text(child.text)
              break if child.name == "h4" && label == "Entreprise"

              fragment.add_child(child.dup)
            end

            fragment.css("button,script,style,nav,footer,aside,svg,use,.added-skills-container").remove
            fragment.xpath("//*[normalize-space(text())='Voir plus']").each(&:remove)
            fragment.css("p").each { |p| p.remove if normalize_text(p.text).nil? }
            fragment.css("h4").each do |heading|
              next unless normalize_text(heading.text) == "Entreprise"

              sibling = heading.next_sibling
              while sibling
                next_sibling = sibling.next_sibling
                sibling.remove
                sibling = next_sibling
              end
              heading.remove
            end

            cleaned = clean_attributes(fragment.to_html.strip)
            return cleaned unless cleaned.empty?
          end

          structured_description = normalize_text(ld["description"])
          return nil if structured_description.nil?

          clean_attributes("<div><h4>Descriptif du poste</h4><p>#{structured_description}</p></div>")
        end

        def extract_json_ld_job_posting(doc)
          doc.css("script[type='application/ld+json']").each do |node|
            parsed = JSON.parse(node.text)
            entries = parsed.is_a?(Array) ? parsed : [parsed]
            candidate = entries.find do |entry|
              entry.is_a?(Hash) && entry["@type"].to_s.match?(/JobPosting/i)
            end
            return candidate if candidate
          rescue JSON::ParserError
            next
          end

          {}
        end

        def text_at(doc, selector)
          normalize_text(doc.at_css(selector)&.text)
        end

        def normalize_text(value)
          return nil if value.nil?

          normalized = value.to_s.gsub("\u00A0", " ").gsub(/[[:space:]]+/, " ").strip
          normalized.empty? ? nil : normalized
        end
      end
    end
  end
end
