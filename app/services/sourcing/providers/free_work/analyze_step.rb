# frozen_string_literal: true

require "json"
require "nokogiri"

module Sourcing
  module Providers
    module FreeWork
      # Parses the stored JSON from FetchStep (Free-Work API job posting payload).
      #
      # FetchStep stores the raw `GET /api/job_postings/<slug>` body, so extraction is
      # fully structural — no HTML scraping, no JSON-LD. Per-field parsers live in
      # ./parsers/.
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 1

        def call(input)
          posting = extract_posting(input[:html_content] || input[:html])

          salary = Parsers::Salary.call(
            min_annual: posting["minAnnualSalary"],
            max_annual: posting["maxAnnualSalary"],
            currency: posting["currency"]
          )

          {
            title: normalize_text(posting["title"]),
            company: normalize_text(posting.dig("company", "name")),
            city: normalize_text(posting.dig("location", "locality")),
            employment_type: Parsers::Contract.call(contracts: posting["contracts"]),
            salary_min_minor: salary[:min],
            salary_max_minor: salary[:max],
            salary_currency: salary[:currency],
            location_mode: Parsers::LocationMode.call(remote_mode: posting["remoteMode"]),
            posted_at: normalize_text(posting["publishedAt"] || posting["createdAt"]),
            description_html: sanitize_description(posting["description"], posting["candidateProfile"]),
          }
        end

        private

        # Returns the job posting hash or `{}` when the payload is malformed. Callers
        # receive `nil` for every field rather than a hard failure — gone-offer
        # detection is FetchStep's responsibility, not analyze's.
        def extract_posting(body)
          data = JSON.parse(body.to_s)
          data.is_a?(Hash) ? data : {}
        rescue JSON::ParserError
          {}
        end

        # The API exposes two HTML blocks: `description` (the mission brief) and
        # `candidateProfile` (candidate requirements). Concatenate both because enrich
        # needs to read requirements (seniority, languages, technologies) which live
        # mostly in `candidateProfile`. `companyDescription` is recruiter boilerplate
        # and is deliberately dropped. Scripts/styles are stripped and class/style
        # attributes removed via the inherited `clean_attributes` for token-efficient
        # enrich.
        def sanitize_description(description_html, candidate_profile_html)
          parts = [description_html, candidate_profile_html].compact.map(&:to_s).reject(&:empty?)
          return nil if parts.empty?

          combined = parts.join("\n")
          fragment = Nokogiri::HTML.fragment(combined)
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
