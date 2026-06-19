# frozen_string_literal: true

require "json"
require "time"
require "nokogiri"
require "kramdown"

module Sourcing
  module Providers
    module Welovedevs
      # Parses the stored JSON from FetchStep (a WeLoveDevs Algolia `public_jobs` object).
      #
      # The hit carries the entire offer, so extraction is fully structural — no HTML
      # scraping, no JSON-LD. The description is markdown (`mdDescription`), rendered to
      # the minimal HTML the pipeline expects. Per-field parsers live in ./parsers/.
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 2

        def call(input)
          hit = extract_hit(input[:html_content] || input[:html])
          details = hit["details"].is_a?(Hash) ? hit["details"] : {}

          salary = Parsers::Salary.call(salary: details["salary"])

          {
            title: normalize_text(hit["title"]),
            company_name: normalize_text(hit.dig("smallCompany", "companyName")),
            city: normalize_text(Array(hit["formattedPlaces"]).first),
            employment_type: Parsers::Contract.call(contract_types: hit["contractTypes"]),
            salary_min_minor: salary[:min],
            salary_max_minor: salary[:max],
            salary_currency: salary[:currency],
            location_mode: Parsers::LocationMode.call(remote_policy: details["remotePolicy"]),
            posted_at: posted_at(hit),
            description_html: sanitize_description(hit["mdDescription"]),
          }
        end

        private

        # Returns the hit hash or `{}` when the payload is malformed. Callers receive
        # `nil` for every field rather than a hard failure — gone-offer detection is
        # FetchStep's responsibility, not analyze's.
        def extract_hit(body)
          data = JSON.parse(body.to_s)
          data.is_a?(Hash) ? data : {}
        rescue JSON::ParserError
          {}
        end

        # WeLoveDevs timestamps are epoch milliseconds. `publishDate` is the offer's
        # publication; `createdAt` is the fallback for older records that predate it.
        def posted_at(hit)
          ms = hit["publishDate"] || hit["createdAt"]
          return nil unless ms.is_a?(Numeric) && ms.positive?

          Time.at(ms / 1000.0).utc.iso8601
        end

        # Renders the markdown description to HTML, then strips presentational attributes
        # via the inherited clean_attributes for token-efficient enrich.
        def sanitize_description(markdown)
          return nil if markdown.nil? || markdown.to_s.strip.empty?

          html = Kramdown::Document.new(markdown.to_s).to_html
          fragment = Nokogiri::HTML.fragment(html)
          fragment.css("script, style").each(&:remove)
          clean_attributes(fragment.to_html).presence
        end

        def normalize_text(value)
          value.to_s.gsub(/\s+/, " ").strip.presence
        end
      end
    end
  end
end
