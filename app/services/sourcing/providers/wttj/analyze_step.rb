# frozen_string_literal: true

require "json"

module Sourcing
  module Providers
    module Wttj
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 3

        # WTTJ renders this banner inline once an offer is taken down. Detecting
        # it lets the pipeline flag the offer as disabled and stop processing it.
        DISABLED_BANNER_PATTERN = /Cette offre n.?est plus disponible/i

        # DOM fallback selectors used when both JSON-LD and __INITIAL_DATA__ are absent.
        TITLE_SELECTORS = ["h1", "h2"].freeze
        COMPANY_SELECTORS = ["a[href*='/companies/']"].freeze
        LOCATION_SELECTORS = ["[class*='location']"].freeze
        CONTRACT_SELECTORS = ["[class*='contract']"].freeze
        SALARY_SELECTORS = ["[class*='salary']"].freeze
        POSTED_AT_SELECTORS = ["[class*='posted']"].freeze
        DESCRIPTION_SELECTORS = ["#the-position-section", "section", ".description"].freeze
        REMOTE_LABELS = [/Télétravail/i, /Remote/i, /Hybride/i, /sur site/i, /présentiel/i, /on[- ]?site/i].freeze

        def call(input)
          html = input[:html] || input[:html_content] || input[:description_html] || ""
          doc = Nokogiri::HTML(html)

          jsonld = extract_jsonld_job(doc)
          embedded_job = extract_embedded_job_data(doc)

          salary_text = extract_first(doc, SALARY_SELECTORS)

          {
            disabled: disabled_offer?(doc),
            title: jsonld["title"] || embedded_job["name"] || extract_first(doc, TITLE_SELECTORS),
            company_name: jsonld.dig("hiringOrganization", "name") || embedded_job.dig("organization", "name") || extract_first(doc, COMPANY_SELECTORS),
            city: jsonld_city(jsonld) || embedded_job.dig("office", "city") || normalize_city(extract_first(doc, LOCATION_SELECTORS)),
            employment_type: normalize_contract_type(jsonld_employment_type(jsonld) || embedded_job["contract_type"] || extract_first(doc, CONTRACT_SELECTORS)),
            salary_min_minor: jsonld_salary_min(jsonld) || embedded_job["salary_min"] || parse_salary_min(salary_text),
            salary_max_minor: jsonld_salary_max(jsonld) || embedded_job["salary_max"] || parse_salary_max(salary_text),
            salary_currency: jsonld_salary_currency(jsonld) || embedded_job["salary_currency"] || parse_salary_currency(salary_text),
            location_mode: normalize_remote_policy(jsonld["jobLocationType"] || embedded_job["remote"] || extract_labeled_text(doc, REMOTE_LABELS)),
            posted_at: jsonld["datePosted"] || extract_relative_posted_at(doc) || parse_posted_at(extract_first(doc, POSTED_AT_SELECTORS)) || embedded_job["published_at"],
            description_html: jsonld["description"] || extract_first_html(doc, DESCRIPTION_SELECTORS) || embedded_job["description"],
          }
        end

        private

        def disabled_offer?(doc)
          doc.text.match?(DISABLED_BANNER_PATTERN)
        end

        def extract_jsonld_job(doc)
          doc.css("script[type='application/ld+json']").each do |node|
            payload = JSON.parse(node.text)
            entries = payload.is_a?(Array) ? payload : [payload]
            entries.each do |entry|
              next unless entry.is_a?(Hash)

              type = entry["@type"]
              return entry if Array(type).map(&:to_s).include?("JobPosting")
            end
          rescue JSON::ParserError
            next
          end
          {}
        end

        def jsonld_city(jsonld)
          value = jsonld["jobLocation"]
          locations = value.is_a?(Array) ? value : [value]
          locations.each do |loc|
            city = loc.is_a?(Hash) && loc.dig("address", "addressLocality")
            return city if city.is_a?(String) && !city.empty?
          end
          nil
        end

        def jsonld_employment_type(jsonld)
          value = jsonld["employmentType"]
          Array(value).first
        end

        def jsonld_salary_min(jsonld)
          base = jsonld["baseSalary"]
          return nil unless base.is_a?(Hash)

          value = base["value"]
          return value["minValue"] if value.is_a?(Hash) && value["minValue"]
          return value if value.is_a?(Numeric)

          nil
        end

        def jsonld_salary_max(jsonld)
          base = jsonld["baseSalary"]
          return nil unless base.is_a?(Hash)

          value = base["value"]
          return value["maxValue"] if value.is_a?(Hash) && value["maxValue"]

          nil
        end

        def jsonld_salary_currency(jsonld)
          base = jsonld["baseSalary"]
          return nil unless base.is_a?(Hash)

          base["currency"]
        end

        def normalize_city(location)
          return nil if location.nil? || location.empty?

          location.split(",").first.strip
        end

        def normalize_contract_type(contract)
          return nil if contract.nil?

          case contract.to_s.strip.downcase
          when /full_time|temps plein|full[- ]?time/ then "FULL_TIME"
          when /part_time|temps partiel|part[- ]?time/ then "PART_TIME"
          when /cdi/ then "PERMANENT"
          when /cdd|fixed[- ]?term/ then "FIXED_TERM"
          when /freelance|contractor/ then "FREELANCE"
          when /stage|intern/ then "INTERNSHIP"
          when /alternance|apprentissage/ then "APPRENTICESHIP"
          when /intérim|interim|temporaire|temporary|temp/ then "TEMPORARY"
          end
        end

        def parse_salary_min(salary)
          return nil if salary.nil? || salary =~ /non spécifié/i

          if salary =~ /(\d+[\sKk]*)[\sà\-]+(\d+[\sKk]*)/i
            raw_min = ::Regexp.last_match(1)
            min = raw_min.gsub(/[\sKk]/, "").to_i
            min *= 1000 if raw_min =~ /[Kk]/
            min
          elsif salary =~ /(\d+[\sKk]*)/i
            raw_min = ::Regexp.last_match(1)
            min = raw_min.gsub(/[\sKk]/, "").to_i
            min *= 1000 if raw_min =~ /[Kk]/
            min
          end
        end

        def parse_salary_max(salary)
          return nil if salary.nil? || salary =~ /non spécifié/i

          if salary =~ /(\d+[\sKk]*)[\sà\-]+(\d+[\sKk]*)/i
            raw_max = ::Regexp.last_match(2)
            max = raw_max.gsub(/[\sKk]/, "").to_i
            max *= 1000 if raw_max =~ /[Kk]/
            max
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
          end
        end

        def normalize_remote_policy(remote)
          return nil if remote.nil?

          case remote.to_s.strip.downcase
          when /telecommute|full[_ ]?remote|^remote$|télétravail total/
            "remote"
          when /partial|hybride|partiel|quelques jours|hybrid/
            "hybrid"
          when /none|no_remote|sur site|on[- ]?site|présentiel/
            "on-site"
          end
        end

        def parse_posted_at(posted)
          return nil if posted.nil?
          return "last month" if posted.match?(/\ble mois dernier\b|\blast month\b/i)

          if posted =~ /il y a (\d+) jours?/
            days_ago = ::Regexp.last_match(1).to_i
            (Time.now - days_ago * 86_400).iso8601
          elsif posted =~ /il y a (\d+) heures?/
            hours_ago = ::Regexp.last_match(1).to_i
            (Time.now - hours_ago * 3600).iso8601
          elsif posted =~ %r{\d{2}/\d{2}/\d{4}}
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
            return clean_attributes(node.inner_html.strip) if node && !node.inner_html.strip.empty?
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
