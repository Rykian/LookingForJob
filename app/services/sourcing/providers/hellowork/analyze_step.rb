# frozen_string_literal: true

require "json"
require "nokogiri"

module Sourcing
  module Providers
    module Hellowork
      # Parses the stored HTML from FetchStep (Hellowork offer detail page).
      # Per-field parsers live in ./parsers/.
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 2

        def call(input)
          html = input[:html_content] || input[:html] || ""
          doc = Nokogiri::HTML(html)
          job_posting = extract_json_ld_job_posting(doc)
          meta_text = extract_meta_text(doc)
          raw_salary = job_posting["baseSalary"] || meta_text[:salary]
          salary = Parsers::Salary.call(raw_salary)

          {
            title: Parsers::Text.normalize(job_posting["title"] || extract_title(doc)),
            company_name: Parsers::Text.normalize(job_posting.dig("hiringOrganization", "name") || extract_company(doc)),
            city: parse_city(job_posting.dig("jobLocation", "address", "addressLocality") || meta_text[:city]),
            employment_type: Parsers::Contract.call(job_posting["employmentType"] || meta_text[:contract]),
            salary_min_minor: salary[:min],
            salary_max_minor: salary[:max],
            salary_currency: salary[:currency],
            location_mode: Parsers::LocationMode.call(
              job_posting: job_posting,
              text_sources: [meta_text[:location_mode], Parsers::Text.html_to_text(job_posting["description"]), doc.text]
            ),
            posted_at: Parsers::PostedAt.call(doc: doc, ld: job_posting),
            description_html: Parsers::Description.call(doc: doc, ld: job_posting),
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
          Parsers::Text.text_at(doc, "h1")
        end

        def extract_company(doc)
          Parsers::Text.text_at(doc, "h1 a[href*='/fr-fr/entreprises/']") ||
            Parsers::Text.text_at(doc, "a[href*='/fr-fr/entreprises/']")
        end

        def extract_meta_text(doc)
          metadata_items = doc.css("h1 + button + ul li, h1 + ul li").map { |n| Parsers::Text.normalize(n.text) }.compact

          {
            city: metadata_items.find { |value| value.match?(/-\s*\d{2}/) },
            contract: metadata_items.find { |value| Parsers::Contract::PATTERNS.any? { |pattern, _| value.match?(pattern) } },
            salary: metadata_items.find { |value| value.match?(/[€$£]/) },
            location_mode: metadata_items.find { |value| value.match?(/t[ée]l[ée]travail|hybride|sur site|pr[ée]sentiel/i) },
          }
        end

        def parse_city(raw)
          text = Parsers::Text.normalize(raw)
          return nil if text.nil? || text.empty?

          text.sub(/\s*-\s*\d{2,3}\z/, "").strip.presence
        end
      end
    end
  end
end
