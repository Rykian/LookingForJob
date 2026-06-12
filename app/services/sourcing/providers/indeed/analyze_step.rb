# frozen_string_literal: true

require "date"
require "json"
require "nokogiri"

module Sourcing
  module Providers
    module Indeed
      # Parses the stored HTML from FetchStep (Indeed /viewjob detail page).
      # Extraction order per field: JSON-LD JobPosting > stable DOM selectors > text heuristics.
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 1

        CONTRACT_PATTERNS = [
          [/\bCDI\b/i,                                       "PERMANENT"],
          [/\bCDD\b/i,                                       "FIXED_TERM"],
          [/alternance|apprentissage|professionnalisation/i, "APPRENTICESHIP"],
          [/\bstage\b|\bintern(?:ship)?\b/i,                 "INTERNSHIP"],
          [/freelance|ind[ée]pendant|contractor/i,           "FREELANCE"],
          [/int[ée]rim|temporary/i,                          "TEMPORARY"],
          [/temps plein|full[-_ ]?time/i,                    "FULL_TIME"],
          [/temps partiel|part[-_ ]?time/i,                  "PART_TIME"],
        ].freeze

        # Indeed JSON-LD employmentType values map directly to our enums.
        JSONLD_CONTRACT_MAP = {
          "FULL_TIME"  => "FULL_TIME",
          "PART_TIME"  => "PART_TIME",
          "CONTRACTOR" => "FREELANCE",
          "TEMPORARY"  => "TEMPORARY",
          "INTERN"     => "INTERNSHIP",
          "VOLUNTEER"  => nil,
          "PER_DIEM"   => "TEMPORARY",
          "OTHER"      => nil,
        }.freeze

        LOCATION_MODE_PATTERNS = [
          [/full[-_ ]?remote|100\s*%\s*(?:remote|t[ée]l[ée]travail)|t[ée]l[ée]travail (?:total|complet|permanent)/i, "remote"],
          [/hybride|hybrid|t[ée]l[ée]travail partiel|2[-–—\s]?3\s*j(?:ours?)?\b|\b[12345]\s*j(?:ours?)?\s*(?:de|en)?\s*t[ée]l[ée]travail/i, "hybrid"],
          [/sur site|on[-_ ]?site|pr[ée]sentiel/i, "on-site"],
        ].freeze

        DESCRIPTION_SELECTOR = "#jobDescriptionText"

        def call(input)
          html = input[:html_content] || input[:html] || ""
          doc = Nokogiri::HTML(html)
          ld  = extract_json_ld_job_posting(doc)
          salary_source = ld["baseSalary"]

          {
            title: normalize_text(ld["title"] || text_at(doc, "h1[data-testid='jobsearch-JobInfoHeader-title']") || text_at(doc, "h1")),
            company_name: normalize_text(ld.dig("hiringOrganization", "name") || text_at(doc, "[data-testid='inlineHeader-companyName']")),
            city: parse_city(ld.dig("jobLocation", "address", "addressLocality") || text_at(doc, "[data-testid='inlineHeader-companyLocation']")),
            employment_type: normalize_contract(ld["employmentType"], doc.text),
            salary_min_minor: parse_salary_min(salary_source),
            salary_max_minor: parse_salary_max(salary_source),
            salary_currency: parse_salary_currency(salary_source),
            location_mode: detect_location_mode(ld, doc),
            posted_at: parse_posted_at(ld["datePosted"]),
            description_html: extract_description_html(doc, ld),
          }
        end

        private

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

        def normalize_contract(jsonld_value, fallback_text)
          if jsonld_value.is_a?(Array)
            jsonld_value.each do |v|
              mapped = JSONLD_CONTRACT_MAP[normalize_text(v).to_s.upcase]
              return mapped if mapped
            end
          elsif jsonld_value.is_a?(String)
            mapped = JSONLD_CONTRACT_MAP[normalize_text(jsonld_value).to_s.upcase]
            return mapped if mapped
          end

          text = normalize_text(fallback_text)
          return nil if text.nil?

          CONTRACT_PATTERNS.each do |pattern, normalized|
            return normalized if text.match?(pattern)
          end

          nil
        end

        def parse_city(raw)
          text = normalize_text(raw)
          return nil if text.nil?

          # Strip postal codes like "Paris (75001)" or "Paris 75001" or "75001 Paris".
          text.sub(/\s*\(?\d{4,5}\)?\s*\z/, "").sub(/\A\d{4,5}\s+/, "").strip.presence
        end

        def parse_salary_min(raw)
          return nil unless raw.is_a?(Hash)

          value = raw["value"]
          return nil unless value.is_a?(Hash)

          amount = (value["minValue"] || value["value"]).to_f
          return nil unless amount.positive?

          to_yearly(amount, value["unitText"])
        end

        def parse_salary_max(raw)
          return nil unless raw.is_a?(Hash)

          value = raw["value"]
          return nil unless value.is_a?(Hash)

          amount = (value["maxValue"] || value["value"]).to_f
          return nil unless amount.positive?

          to_yearly(amount, value["unitText"])
        end

        def parse_salary_currency(raw)
          return nil unless raw.is_a?(Hash)

          currency = normalize_text(raw["currency"])
          currency&.upcase&.presence
        end

        def to_yearly(amount, unit_text)
          case normalize_text(unit_text).to_s.upcase
          when "MONTH" then (amount * 12).to_i
          when "WEEK"  then (amount * 52).to_i
          when "DAY"   then (amount * 220).to_i
          when "HOUR"  then (amount * 1_820).to_i
          else amount.to_i
          end
        end

        def detect_location_mode(ld, doc)
          return "remote" if ld["jobLocationType"].to_s.match?(/TELECOMMUTE/i)

          # Indeed sometimes signals remote in jobLocation address country code
          # or via job attribute badges.
          haystack = [
            text_at(doc, "[data-testid='inlineHeader-companyLocation']"),
            text_at(doc, "#jobDescriptionText"),
            doc.css("[data-testid$='-tile'], [class*='Pill'], [class*='attribute']").map(&:text).join(" "),
          ].compact.map { |t| normalize_text(t) }.compact.join(" ")

          LOCATION_MODE_PATTERNS.each do |pattern, mode|
            return mode if haystack.match?(pattern)
          end

          nil
        end

        def parse_posted_at(raw)
          text = normalize_text(raw)
          return nil if text.nil?

          Date.parse(text).iso8601
        rescue Date::Error, ArgumentError
          nil
        end

        def extract_description_html(doc, ld)
          node = doc.at_css(DESCRIPTION_SELECTOR)
          if node
            fragment = Nokogiri::HTML.fragment(node.inner_html)
            fragment.css("script,style,noscript,svg,use,nav,footer,button").remove
            cleaned = clean_attributes(fragment.to_html.strip)
            return cleaned unless cleaned.empty?
          end

          raw = ld["description"].to_s
          return nil if raw.strip.empty?

          # JSON-LD descriptions on Indeed are typically HTML strings already.
          clean_attributes(raw)
        end

        def text_at(doc, selector)
          normalize_text(doc.at_css(selector)&.text)
        end

        def normalize_text(value)
          return nil if value.nil?

          normalized = value.to_s.gsub(" ", " ").gsub(/[[:space:]]+/, " ").strip
          normalized.empty? ? nil : normalized
        end
      end
    end
  end
end
