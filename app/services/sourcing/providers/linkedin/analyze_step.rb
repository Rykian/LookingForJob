# frozen_string_literal: true

require "nokogiri"

module Sourcing
  module Providers
    module Linkedin
      # Parses the LinkedIn guest job-detail HTML into pipeline fields.
      #
      # LinkedIn does NOT expose JSON-LD JobPosting on guest pages, so this step relies
      # on stable DOM selectors documented in providers/linkedin/README.md. Failure modes
      # (missing title element, missing description, auth-wall content) are caught earlier
      # in FetchStep, so missing optional fields here are treated as nil rather than errors.
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 2

        # LinkedIn "Employment type" criteria values mapped onto JobOffer::EMPLOYMENT_TYPES enum keys.
        EMPLOYMENT_TYPE_MAP = {
          "full-time"        => "full_time",
          "part-time"        => "part_time",
          "contract"         => "contract",
          "temporary"        => "temporary",
          "internship"       => "internship",
          "apprenticeship"   => "apprenticeship",
          "volunteer"        => nil,
          "other"            => nil,
        }.freeze

        def call(input)
          html = input[:html_content] || input[:html] || ""
          doc  = Nokogiri::HTML.fragment(html)

          criteria = extract_criteria(doc)

          {
            title:            text_at(doc, "h2.top-card-layout__title, h1.top-card-layout__title"),
            company:          text_at(doc, "a.topcard__org-name-link, span.topcard__flavor"),
            city:             parse_city(text_at(doc, "span.topcard__flavor.topcard__flavor--bullet")),
            employment_type:  normalize_employment_type(criteria["Employment type"]),
            salary_min_minor: nil,
            salary_max_minor: nil,
            salary_currency:  nil,
            location_mode:    nil,
            posted_at:        Parsers::PostedAt.call(text_at(doc, "span.posted-time-ago__text")),
            description_html: clean_attributes(extract_description_html(doc)),
          }
        end

        private

        def text_at(doc, selector)
          node = doc.at_css(selector)
          node&.text&.strip&.presence
        end

        # Returns a flat hash like {"Seniority level"=>"Mid-Senior level", "Employment type"=>"Full-time", ...}
        def extract_criteria(doc)
          doc.css("li.description__job-criteria-item").each_with_object({}) do |li, acc|
            key   = li.at_css(".description__job-criteria-subheader")&.text&.strip
            value = li.at_css(".description__job-criteria-text")&.text&.strip
            acc[key] = value if key && value && !value.empty?
          end
        end

        def normalize_employment_type(raw)
          return nil if raw.nil?

          EMPLOYMENT_TYPE_MAP[raw.strip.downcase]
        end

        def parse_city(raw)
          return nil if raw.nil?

          # LinkedIn location format: "City, Region, Country" — keep only the city.
          first = raw.split(",").first&.strip
          first.presence
        end

        def extract_description_html(doc)
          node = doc.at_css("div.show-more-less-html__markup, div.description__text")
          return nil unless node

          # Strip script/style nodes; clean_attributes (inherited) removes style/class on the rest.
          node.css("script, style").each(&:remove)
          node.inner_html.strip.presence
        end
      end
    end
  end
end
