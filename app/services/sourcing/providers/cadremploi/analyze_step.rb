# frozen_string_literal: true

require "nokogiri"
require "json"

module Sourcing
  module Providers
    module Cadremploi
      # Parses the stored HTML from FetchStep (Cadremploi offer detail page).
      # Extraction order per field: JSON-LD JobPosting > semantic CSS selectors > text heuristics.
      # Per-field parsers live in ./parsers/.
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 1

        def call(input)
          html = input[:html_content] || input[:html] || ""
          doc  = Nokogiri::HTML(html)
          ld   = extract_json_ld(doc)

          salary = Parsers::Salary.call(doc: doc, ld: ld)

          {
            title: ld["title"] || text_at(doc, "h1"),
            company: ld.dig("hiringOrganization", "name") || extract_company(doc),
            city: parse_city(ld.dig("jobLocation", "address", "addressLocality") || extract_city(doc)),
            employment_type: Parsers::Contract.call(doc: doc, ld: ld),
            salary_min_minor: salary[:min],
            salary_max_minor: salary[:max],
            salary_currency: salary[:currency],
            location_mode: Parsers::LocationMode.call(doc: doc, ld: ld),
            posted_at: Parsers::PostedAt.call(doc: doc, ld: ld),
            description_html: Parsers::Description.call(doc: doc, ld: ld),
          }
        end

        private

        def extract_json_ld(doc)
          doc.css("script[type='application/ld+json']").each do |script|
            data = JSON.parse(script.text.strip)
            nodes = data.is_a?(Array) ? data : [data]
            candidate = nodes.find { |n| n.is_a?(Hash) && n["@type"].to_s =~ /JobPosting/i }
            return candidate if candidate
          rescue JSON::ParserError
            next
          end
          {}
        end

        def extract_company(doc)
          node = doc.at_css("h3") ||
                 doc.at_css("[class*='company-name']") ||
                 doc.at_css("[class*='recruiter']")
          node&.text&.strip&.presence
        end

        def extract_city(doc)
          node = doc.at_css("[itemprop='addressLocality']") ||
                 doc.at_css("[class*='location']") ||
                 doc.at_css("[class*='city']") ||
                 doc.at_css("[class*='localisation']")
          node&.text&.strip&.presence
        end

        def parse_city(raw)
          return nil if raw.nil? || raw.strip.empty?

          raw.sub(/\A\d+\s*[-–]\s*/, "").strip.presence
        end

        def text_at(doc, selector)
          doc.at_css(selector)&.text&.strip&.presence
        end
      end
    end
  end
end
