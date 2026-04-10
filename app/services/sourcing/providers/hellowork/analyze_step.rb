# frozen_string_literal: true

require "json"
require "nokogiri"
require "set"

module Sourcing
  module Providers
    module Hellowork
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 2

        CONTRACT_PATTERNS = [
          [/\bCDI\b/i,                                        "PERMANENT"],
          [/\bCDD\b/i,                                        "FIXED_TERM"],
          [/alternance|apprentissage|professionnalisation/i, "APPRENTICESHIP"],
          [/\bstage\b/i,                                     "INTERNSHIP"],
          [/freelance|ind[ée]pendant/i,                      "FREELANCE"],
          [/int[ée]rim|temporaire/i,                         "TEMPORARY"],
          [/full[-_ ]?time|temps plein/i,                    "FULL_TIME"],
          [/part[-_ ]?time|temps partiel/i,                  "PART_TIME"],
        ].freeze

        LOCATION_MODE_PATTERNS = [
          [/t[ée]l[ée]travail total|100\s*%\s*t[ée]l[ée]travail|full[-_ ]?remote/i, "remote"],
          [/t[ée]l[ée]travail partiel|hybride|occasionnel|\b\d+\s*jours\b/i,       "hybrid"],
          [/sur site|pr[ée]sentiel|on[-_ ]?site/i,                                    "on-site"],
        ].freeze

        SALARY_RANGE_REGEXP = /(\d[\d\s]+)\s*[-–]\s*(\d[\d\s]+)\s*[€$£]/.freeze
        SALARY_SINGLE_REGEXP = /(\d[\d\s]+)\s*[€$£]/.freeze
        DESCRIPTION_SECTION_PATTERNS = [
          /d[ée]tail du poste/i,
          /missions? du poste/i,
          /profil recherch/i,
          /avantages?/i,
          /infos? compl[ée]mentaires?/i,
          /bienvenue chez/i,
          /comp[ée]tences?/i,
          /stack technique/i,
        ].freeze

        def call(input)
          html = input[:html_content] || input[:html] || ""
          doc = Nokogiri::HTML(html)
          job_posting = extract_json_ld_job_posting(doc)
          meta_text = extract_meta_text(doc)
          raw_salary = job_posting["baseSalary"] || meta_text[:salary]

          {
            title: normalize_text(job_posting["title"] || extract_title(doc)),
            company: normalize_text(job_posting.dig("hiringOrganization", "name") || extract_company(doc)),
            city: parse_city(job_posting.dig("jobLocation", "address", "addressLocality") || meta_text[:city]),
            employment_type: normalize_contract(job_posting["employmentType"] || meta_text[:contract]),
            salary_min_minor: parse_salary_min(raw_salary),
            salary_max_minor: parse_salary_max(raw_salary),
            salary_currency: parse_salary_currency(raw_salary),
            location_mode: detect_location_mode(job_posting: job_posting, text_sources: [meta_text[:location_mode], html_to_text(job_posting["description"]), doc.text]),
            posted_at: parse_posted_at(job_posting["datePosted"] || extract_posted_at(doc)),
            description_html: extract_description_html(doc, job_posting: job_posting),
          }
        end

        private

        def extract_json_ld_job_posting(doc)
          doc.css("script[type='application/ld+json']").each do |node|
            parsed = JSON.parse(node.text)
            entries = parsed.is_a?(Array) ? parsed : [parsed]
            candidate = entries.find { |entry| entry.is_a?(Hash) && entry["@type"].to_s.match?(/JobPosting/i) }
            return candidate if candidate
          rescue JSON::ParserError
            next
          end

          {}
        end

        def extract_title(doc)
          text_at(doc, "h1")
        end

        def extract_company(doc)
          text_at(doc, "h1 a[href*='/fr-fr/entreprises/']") || text_at(doc, "a[href*='/fr-fr/entreprises/']")
        end

        def extract_meta_text(doc)
          metadata_items = doc.css("h1 + button + ul li, h1 + ul li").map { |n| normalize_text(n.text) }.compact

          {
            city: metadata_items.find { |value| value.match?(/-\s*\d{2}/) },
            contract: metadata_items.find { |value| CONTRACT_PATTERNS.any? { |pattern, _| value.match?(pattern) } },
            salary: metadata_items.find { |value| value.match?(/[€$£]/) },
            location_mode: metadata_items.find { |value| value.match?(/t[ée]l[ée]travail|hybride|sur site|pr[ée]sentiel/i) },
          }
        end

        def parse_city(raw)
          text = normalize_text(raw)
          return nil if text.nil? || text.empty?

          text.sub(/\s*-\s*\d{2,3}\z/, "").strip.presence
        end

        def normalize_contract(raw)
          value = normalize_text(raw)
          return nil if value.nil? || value.empty?

          CONTRACT_PATTERNS.each do |pattern, normalized|
            return normalized if value.match?(pattern)
          end

          nil
        end

        def parse_salary_min(raw)
          return parse_salary_value(raw, key: "minValue") if raw.is_a?(Hash)

          text = normalize_text(raw)
          return nil if text.nil?

          if (match = text.match(SALARY_RANGE_REGEXP))
            to_minor_amount(match[1])
          elsif (match = text.match(SALARY_SINGLE_REGEXP))
            to_minor_amount(match[1])
          end
        end

        def parse_salary_max(raw)
          return parse_salary_value(raw, key: "maxValue") if raw.is_a?(Hash)

          text = normalize_text(raw)
          return nil if text.nil?

          match = text.match(SALARY_RANGE_REGEXP)
          match ? to_minor_amount(match[2]) : nil
        end

        def parse_salary_currency(raw)
          return raw["currency"].to_s.upcase.presence if raw.is_a?(Hash)

          text = normalize_text(raw)
          return nil if text.nil?
          return "EUR" if text.match?(/€|eur/i)
          return "USD" if text.match?(/\$/)
          return "GBP" if text.match?(/£|gbp/i)

          nil
        end

        def parse_salary_value(raw, key:)
          value = raw.dig("value", key)
          return nil unless value

          amount = value.to_f
          return nil unless amount.positive?

          unit_text = raw.dig("value", "unitText").to_s.upcase
          yearly = unit_text == "MONTH" ? amount * 12 : amount
          yearly.to_i
        end

        def to_minor_amount(raw)
          digits = raw.to_s.gsub(/[^\d]/, "")
          return nil if digits.empty?

          digits.to_i
        end

        def detect_location_mode(job_posting:, text_sources:)
          text_sources.compact.each do |raw_text|
            text = normalize_text(raw_text)
            next if text.nil?

            LOCATION_MODE_PATTERNS.each do |pattern, mode|
              return mode if text.match?(pattern)
            end
          end

          type = job_posting["jobLocationType"].to_s
          return "remote" if type.match?(/TELECOMMUTE/i)

          nil
        end

        def extract_posted_at(doc)
          text = text_at(doc, "[aria-label*='Publi']") || text_at(doc, "*[class*='published']")
          return nil unless text

          date_match = text.match(/(\d{2})\/(\d{2})\/(\d{4})/)
          return nil unless date_match

          "#{date_match[3]}-#{date_match[2]}-#{date_match[1]}"
        end

        def parse_posted_at(raw)
          value = normalize_text(raw)
          return nil if value.nil?
          return value if value.match?(/\A\d{4}-\d{2}-\d{2}(?:T.*)?\z/)

          nil
        end

        def extract_description_html(doc, job_posting:)
          description = extract_description_sections(doc)
          description ||= job_posting["description"]

          cleaned = strip_non_content_nodes(description)
          cleaned = clean_attributes(cleaned)
          cleaned.nil? || cleaned.empty? ? nil : cleaned
        end

        def strip_non_content_nodes(raw_html)
          return raw_html if raw_html.nil? || raw_html.empty?

          fragment = Nokogiri::HTML.fragment(raw_html)
          fragment.css("script,style,nav,footer,aside,button,svg,use").remove
          fragment.to_html
        end

        def extract_description_sections(doc)
          blocks = []
          seen_texts = Set.new

          doc.css("section, details").each do |container|
            heading = extract_section_heading(container)
            next unless include_description_section?(heading)

            block_html = build_section_block(container, heading)
            next if block_html.nil?

            block_text = html_to_text(block_html)
            next if block_text.nil? || seen_texts.include?(block_text)

            blocks << block_html
            seen_texts << block_text
          end

          if blocks.empty?
            doc.css("h2").each do |h2|
              heading_text = normalize_text(h2.text)
              next unless include_description_section?(heading_text)

              fragments = [h2.to_html]
              node = h2.next_element
              while node && node.name != "h2"
                fragments << node.to_html
                node = node.next_element
              end

              block_html = fragments.join
              block_text = html_to_text(block_html)
              next if block_text.nil? || seen_texts.include?(block_text)

              blocks << block_html
              seen_texts << block_text
            end
          end

          return nil if blocks.empty?

          blocks.join("\n")
        end

        def include_description_section?(heading)
          heading_text = normalize_text(heading)
          return false if heading_text.nil?

          DESCRIPTION_SECTION_PATTERNS.any? { |pattern| heading_text.match?(pattern) }
        end

        def extract_section_heading(container)
          heading_node = if container.name == "details"
            container.at_css("summary h2 span") || container.at_css("summary h2") || container.at_css("summary")
          else
            container.at_css("h2 span") || container.at_css("h2")
          end

          normalize_text(heading_node&.text)
        end

        def build_section_block(container, heading)
          heading_html = "<h2>#{heading}</h2>"
          content_html = extract_section_content_html(container)
          return nil if content_html.nil?

          "#{heading_html}\n#{content_html}"
        end

        def extract_section_content_html(container)
          if (expanded_content = container.at_css("[data-truncate-text-target='content']"))
            return expanded_content.to_html
          end

          if container.name == "details"
            content_nodes = container.element_children.reject { |child| child.name == "summary" }
            content_html = content_nodes.map(&:to_html).join("\n")
            return content_html unless content_html.empty?
          end

          content_nodes = container.element_children.reject do |child|
            child.name == "h2" || child.name == "summary"
          end
          content_html = content_nodes.map(&:to_html).join("\n")
          content_html.empty? ? nil : content_html
        end

        def html_to_text(raw_html)
          value = raw_html.to_s
          return nil if value.empty?

          normalize_text(Nokogiri::HTML.fragment(value).text)
        end

        def normalize_text(value)
          return nil if value.nil?

          normalized = value.to_s.gsub("\u00A0", " ").gsub(/\s+/, " ").strip
          normalized.empty? ? nil : normalized
        end

        def text_at(doc, selector)
          normalize_text(doc.at_css(selector)&.text)
        end
      end
    end
  end
end
