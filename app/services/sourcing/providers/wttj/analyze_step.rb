# frozen_string_literal: true

require "json"

module Sourcing
  module Providers
    module Wttj
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 1

        # Selectors for fixed fields
        TITLE_SELECTORS = ["h2"].freeze
        COMPANY_SELECTORS = ["a[href*='/companies/']"].freeze
        LOCATION_SELECTORS = ["[class*='location']"].freeze
        CONTRACT_SELECTORS = ["[class*='contract']"].freeze
        SALARY_SELECTORS = ["[class*='salary']"].freeze
        POSTED_AT_SELECTORS = ["[class*='posted']"].freeze
        REMOTE_LABELS = [/Télétravail/i, /Remote/i, /télétravail/i, /remote/i, /Hybride/i, /sur site/i, /présentiel/i, /on[- ]?site/i].freeze

        def call(input)
          html = input[:html] || input[:html_content] || input[:description_html] || ""
          doc = Nokogiri::HTML(html)
          embedded_job = extract_embedded_job_data(doc)
          salary_text = extract_first(doc, SALARY_SELECTORS)

          {
            title: embedded_job["name"] || extract_first(doc, TITLE_SELECTORS),
            company: embedded_job.dig("organization", "name") || extract_first(doc, COMPANY_SELECTORS),
            city: embedded_job.dig("office", "city") || normalize_city(extract_first(doc, LOCATION_SELECTORS)),
            employment_type: normalize_contract_type(embedded_job["contract_type"] || extract_first(doc, CONTRACT_SELECTORS)),
            salary_min_minor: embedded_job["salary_min"] || parse_salary_min(salary_text),
            salary_max_minor: embedded_job["salary_max"] || parse_salary_max(salary_text),
            salary_currency: embedded_job["salary_currency"] || parse_salary_currency(salary_text),
            location_mode: normalize_remote_policy(embedded_job["remote"] || extract_labeled_text(doc, REMOTE_LABELS)),
            posted_at: extract_relative_posted_at(doc) || parse_posted_at(extract_first(doc, POSTED_AT_SELECTORS)) || embedded_job["published_at"],
            description_html: extract_first_html(doc, ["#the-position-section", "section", ".description"]) || embedded_job["description"],
          }
        end

        private

        # --- Normalization helpers for DB compatibility ---
        def normalize_city(location)
          return nil if location.nil? || location.empty?

          # Pick the first city if multiple are listed
          location.split(",").first.strip
        end

        def normalize_contract_type(contract)
          return nil if contract.nil?

          case contract.strip.downcase
          when /full_time/ then "PERMANENT"
          when /cdi/ then "PERMANENT"
          when /temporary|temp/ then "TEMPORARY"
          when /cdd/ then "FIXED_TERM"
          when /freelance/ then "FREELANCE"
          when /stage/ then "INTERNSHIP"
          when /alternance|apprentissage/ then "APPRENTICESHIP"
          when /intérim|interim|temporaire/ then "TEMPORARY"
          when /temps plein|full[- ]?time/ then "FULL_TIME"
          when /temps partiel|part[- ]?time/ then "PART_TIME"
          else
            nil
          end
        end

        def parse_salary_min(salary)
          return nil if salary.nil? || salary =~ /non spécifié/i

          # Match "50K à 80K €" or "50 000 - 80 000 EUR"
          if salary =~ /(\d+[\sKk]*)[\sà\-]+(\d+[\sKk]*)/i
            raw_min = $1
            min = raw_min.gsub(/[\sKk]/, "").to_i
            min *= 1000 if raw_min =~ /[Kk]/
            min
          elsif salary =~ /(\d+[\sKk]*)/i
            raw_min = $1
            min = raw_min.gsub(/[\sKk]/, "").to_i
            min *= 1000 if raw_min =~ /[Kk]/
            min
          else
            nil
          end
        end

        def parse_salary_max(salary)
          return nil if salary.nil? || salary =~ /non spécifié/i

          if salary =~ /(\d+[\sKk]*)[\sà\-]+(\d+[\sKk]*)/i
            raw_max = $2
            max = raw_max.gsub(/[\sKk]/, "").to_i
            max *= 1000 if raw_max =~ /[Kk]/
            max
          else
            nil
          end
        end

        def parse_salary_currency(salary)
          return nil if salary.nil? || salary =~ /non spécifié/i

          if salary =~ /€|eur/i
            "EUR"
          elsif salary =~ /\$/
            "USD"
          elsif salary =~ /£|gbp/i
            "GBP"
          else
            nil
          end
        end

        def normalize_remote_policy(remote)
          return nil if remote.nil?

          case remote.strip.downcase
          when /partial|hybride|partiel|quelques jours/
            "hybrid"
          when /full remote|full_remote|remote|full/i
            "remote"
          when /none|no_remote/
            "on-site"
          when /télétravail total|full remote|remote/i
            "remote"
          when /hybride|partiel|quelques jours/i
            "hybrid"
          when /sur site|on[- ]?site|présentiel/i
            "on-site"
          else
            nil
          end
        end

        def parse_posted_at(posted)
          return nil if posted.nil?

          return "last month" if posted.match?(/\ble mois dernier\b|\blast month\b/i)

          # Example: "il y a 8 jours"
          if posted =~ /il y a (\d+) jours?/
            days_ago = $1.to_i
            (Time.now - days_ago * 86_400).iso8601
          elsif posted =~ /il y a (\d+) heures?/
            hours_ago = $1.to_i
            (Time.now - hours_ago * 3600).iso8601
          elsif posted =~ /\d{2}\/\d{2}\/\d{4}/
            # Format: 31/03/2026
            Date.strptime(posted, "%d/%m/%Y").to_time.iso8601
          else
            posted
          end
        end

        def extract_first(doc, selectors)
          selectors.each do |selector|
            node = doc.at_css(selector)
            return node.text.strip if node && !node.text.strip.empty?
          end
          nil
        end

        def extract_first_html(doc, selectors)
          selectors.each do |selector|
            node = doc.at_css(selector)
            return node.inner_html.strip if node && !node.inner_html.strip.empty?
          end
          nil
        end

        def extract_labeled_text(doc, label_regexes)
          doc.xpath("//*[self::p or self::li or self::div or self::span]").each do |node|
            label_regexes.each do |regex|
              return node.text.strip if node.text =~ regex
            end
          end
          nil
        end

        def extract_relative_posted_at(doc)
          text = doc.text.gsub(/\s+/, " ").strip
          return "last month" if text.match?(/\ble mois dernier\b|\blast month\b/i)

          nil
        end

        def extract_embedded_job_data(doc)
          data = extract_embedded_initial_data(doc)
          return {} unless data.is_a?(Hash)

          query = Array(data["queries"]).find do |entry|
            Array(entry["queryKey"]).first == "job"
          end

          query&.dig("state", "data") || {}
        end

        def extract_embedded_initial_data(doc)
          script = doc.css("script").find { |node| node.text.include?("window.__INITIAL_DATA__") }
          return nil unless script

          match = script.text.match(/window\.__INITIAL_DATA__\s*=\s*("(?:\\.|[^"])*")/m)
          return nil unless match

          decoded = JSON.parse(match[1])
          JSON.parse(decoded)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
