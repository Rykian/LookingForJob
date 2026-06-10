# frozen_string_literal: true

require "json"

module Sourcing
  module Providers
    module CollectiveWork
      # Parses the stored HTML from FetchStep (Collective.work offer detail page).
      #
      # Extraction is __NEXT_DATA__-first: the SSR payload at
      # `props.pageProps.project` carries every field structurally (no JSON-LD is
      # emitted on this site, and DOM scraping is brittle on a React-rendered page).
      # Per-field parsers live in ./parsers/.
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 1

        NEXT_DATA_REGEXP = %r{<script id="__NEXT_DATA__"[^>]*>(.*?)</script>}m

        def call(input)
          html = input[:html_content] || input[:html] || ""
          project = extract_project(html)

          salary = Parsers::Salary.call(
            budget_brief: project["budgetBrief"],
            is_permanent_contract: project["isPermanentContract"]
          )

          {
            title: normalize_text(project["name"]),
            company: normalize_text(project.dig("company", "name")),
            city: city_from(project["location"]),
            employment_type: Parsers::Contract.call(is_permanent_contract: project["isPermanentContract"]),
            salary_min_minor: salary[:min],
            salary_max_minor: salary[:max],
            salary_currency: salary[:currency],
            location_mode: Parsers::LocationMode.call(work_preferences: project["workPreferences"]),
            posted_at: normalize_text(project["publishedAt"] || project["createdAt"]),
            description_html: sanitize_description(project["description"], project["profileWanted"]),
          }
        end

        private

        # Returns the `project` hash or `{}` when missing. Callers receive `nil` for
        # every field rather than a hard failure — gone-offer detection is FetchStep's
        # responsibility, not analyze's.
        def extract_project(html)
          match = html.to_s.match(NEXT_DATA_REGEXP)
          return {} unless match

          data = JSON.parse(match[1])
          project = data.dig("props", "pageProps", "project")
          project.is_a?(Hash) ? project : {}
        rescue JSON::ParserError
          {}
        end

        def city_from(location)
          return nil unless location.is_a?(Hash)

          raw = location["fullNameFrench"] || location["fullNameEnglish"]
          # "Paris, France" → "Paris"; bare "Paris" stays as-is.
          normalize_text(raw.to_s.split(",").first)
        end

        # The detail page exposes two HTML blocks: `description` (the mission brief) and
        # `profileWanted` (candidate requirements). Concatenate both because enrich needs
        # to read requirements (seniority, English level, technologies) which live mostly
        # in `profileWanted`. Scripts/styles are stripped and class/style attributes
        # removed via the inherited `clean_attributes` for token-efficient enrich.
        def sanitize_description(description_html, profile_wanted_html)
          parts = [description_html, profile_wanted_html].compact.map(&:to_s).reject(&:empty?)
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
