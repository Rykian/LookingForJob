# frozen_string_literal: true

require "nokogiri"
require "json"

module Sourcing
  module Providers
    module Welovedevs
      # Parses the stored HTML from FetchStep (WeLoveDevs offer detail page).
      #
      # WeLoveDevs embeds a complete JSON-LD JobPosting on every offer page, so extraction
      # is JSON-LD first. The templated meta description is used as a secondary text signal
      # for contract type and remote granularity that the JSON-LD flattens. Per-field
      # parsers live in ./parsers/.
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 1

        def call(input)
          html = input[:html_content] || input[:html] || ""
          doc  = Nokogiri::HTML(html)
          ld   = extract_json_ld(doc)
          meta = meta_description(doc)

          salary = Parsers::Salary.call(ld: ld, text: meta)

          {
            title: normalize_text(ld["title"]) || text_at(doc, "h1"),
            company_name: normalize_text(ld.dig("hiringOrganization", "name")),
            city: normalize_text(ld.dig("jobLocation", "address", "addressLocality")),
            employment_type: Parsers::Contract.call(ld: ld, text: meta),
            salary_min_minor: salary[:min],
            salary_max_minor: salary[:max],
            salary_currency: salary[:currency],
            location_mode: Parsers::LocationMode.call(doc: doc, ld: ld, text: meta, html: html),
            posted_at: normalize_text(ld["datePosted"]),
            description_html: sanitize_description(ld["description"].presence || dom_description(doc)),
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

        def meta_description(doc)
          doc.at_css("meta[name='description']")&.[]("content").to_s
        end

        def dom_description(doc)
          node = doc.at_css("article") || doc.at_css("[class*='description']")
          node&.inner_html&.strip&.presence
        end

        # Strips script/style nodes, then removes style/class attributes via the inherited
        # clean_attributes, keeping the smallest meaningful HTML for token-efficient enrich.
        def sanitize_description(html)
          return nil if html.nil? || html.to_s.strip.empty?

          fragment = Nokogiri::HTML.fragment(html)
          fragment.css("script, style").each(&:remove)
          clean_attributes(fragment.to_html)
        end

        def text_at(doc, selector)
          doc.at_css(selector)&.text&.strip&.presence
        end

        def normalize_text(value)
          value.to_s.gsub(/\s+/, " ").strip.presence
        end
      end
    end
  end
end
