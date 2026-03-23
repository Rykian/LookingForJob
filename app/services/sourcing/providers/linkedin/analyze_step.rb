require "nokogiri"
require "json"
require "bigdecimal"

module Sourcing
  module Providers
    module Linkedin
      class AnalyzeStep < Sourcing::AnalyzeStep
        TITLE_SELECTORS = [
          ".job-details-jobs-unified-top-card__job-title h1",
          "h1.t-24",
          "h1.jobs-unified-top-card__job-title",
          ".top-card-layout__title",
          ".topcard__title",
          "h1"
        ].freeze

        COMPANY_SELECTORS = [
          ".job-details-jobs-unified-top-card__company-name a",
          ".job-details-jobs-unified-top-card__company-name",
          ".jobs-unified-top-card__company-name a",
          ".jobs-unified-top-card__company-name",
          ".topcard__org-name-link",
          ".topcard__flavor--black-link",
          ".topcard__flavor"
        ].freeze

        POSTED_AT_SELECTORS = [
          ".posted-time-ago__text",
          ".jobs-unified-top-card__posted-date",
          ".jobs-unified-top-card__subtitle-primary-grouping span",
          ".topcard__flavor--metadata"
        ].freeze

        LOCATION_SELECTORS = [
          ".job-details-jobs-unified-top-card__primary-description-container",
          ".jobs-unified-top-card__subtitle-primary-grouping",
          ".topcard__flavor--bullet"
        ].freeze

        CURRENCY_BY_SYMBOL = {
          "€" => "EUR",
          "$" => "USD",
          "£" => "GBP"
        }.freeze

        LOCATION_NOISE_TOKENS = %w[
          engineer
          developer
          software
          backend
          front
          frontend
          fullstack
          full-stack
          stack
          ruby
          rails
          junior
          senior
          lead
          principal
          stage
          intern
          internship
          alternance
          apprentice
          apprenticeship
        ].freeze

        DESCRIPTION_SELECTORS = [
          "[data-testid='expandable-text-box']",
          "#job-details",
          ".jobs-description__content",
          ".show-more-less-html__markup"
        ].freeze

        def call(input)
          html = input.fetch(:html_content)
          doc = Nokogiri::HTML(html)
          job_posting = extract_job_posting_json_ld(doc)
          title = extract_title(doc, job_posting)
          company = extract_company(doc, job_posting)
          page_text = normalize_whitespace(doc.text)
          salary = extract_salary(doc, page_text, job_posting)

          {
            title: title,
            company: company,
            remote: map_remote(page_text),
            employment_type: map_employment_type(page_text),
            description_html: extract_description_html(doc),
            salary_min_minor: salary[:salary_min_minor],
            salary_max_minor: salary[:salary_max_minor],
            salary_currency: salary[:salary_currency],
            posted_at: extract_posted_at(doc, job_posting, page_text),
            city: extract_city(doc, page_text)
          }
        end

        private

        def extract_first_text(doc, selectors)
          selectors.each do |selector|
            text = normalize_whitespace(doc.at_css(selector)&.text)
            return text if text && !text.empty?
          end
          nil
        end

        def extract_city(doc, page_text)
          # Prefer node-level extraction to avoid capturing neighboring phrases.
          node = doc.at_xpath("//*[contains(normalize-space(text()), 'Location:')]")
          if node
            node_text = normalize_whitespace(node.text)
            value = node_text.split("Location:", 2).last
            city = normalize_location(value)
            return city unless city.nil?
          end

          city = extract_city_from_selectors(doc)
          return city unless city.nil?

          # LinkedIn top-card location often appears as:
          # "Paris, Ile-de-France, France · Reposted 1 day ago"
          france_location = extract_french_location_triplet(page_text)
          if france_location
            city = normalize_location(france_location)
            return city unless city.nil?
          end

          # Variant found in some locales/snapshots:
          # "Paris Metropolitan Region · Reposted ..."
          # or "Greater Paris Metropolitan Region (On-site)"
          match = page_text.match(/([A-Za-zÀ-ÿ'\- ]+\s+Metropolitan Region)(?:\s*·|\s*\(|\s{2,}|$)/i)
          if match
            city = normalize_location(match[1])
            return city unless city.nil?
          end

          # Fallback for explicit location labels in text-only pages.
          match = page_text.match(/Location:\s*([A-Za-zÀ-ÿ'\- ]+?)(?:\s{2,}|$|,|\.|;)/i)
          normalize_location(match && match[1])
        end

        def extract_city_from_selectors(doc)
          LOCATION_SELECTORS.each do |selector|
            doc.css(selector).each do |node|
              text = normalize_whitespace(node.text)
              next if text.empty?

              city = location_candidate_from_text(text)
              return city unless city.nil?
            end
          end

          nil
        end

        def location_candidate_from_text(text)
          candidate = text.split("·", 2).first
          candidate = candidate.sub(/\((?:on\s*-?\s*site|hybrid|remote)\)/i, "")
          candidate = normalize_location(candidate)
          return nil if candidate.nil?

          return candidate if candidate.match?(/\bFrance\b/i)
          return candidate if candidate.match?(/\bet\s+périphérie\b/i)

          nil
        end

        def extract_french_location_triplet(text)
          matches = text.scan(/([A-Za-zÀ-ÿ'\- ]+?,\s*[A-Za-zÀ-ÿ'\- ]+,\s*France)\b/i)
          return nil if matches.empty?

          raw = matches.last[0]
          return nil if raw.nil? || raw.empty?

          parts = raw.split(",", 3).map { |part| normalize_whitespace(part) }
          return nil unless parts.size == 3

          city = sanitize_city_prefix(parts[0])
          region = parts[1]
          country = parts[2]
          return nil if city.empty? || region.empty? || country.empty?

          "#{city}, #{region}, #{country}"
        end

        def sanitize_city_prefix(value)
          words = value.split(/\s+/)
          return value if words.empty?

          # LinkedIn shell text can prepend job-title/menu words before the city.
          # Keep the tail after the last known noisy token when present.
          indexes = words.each_index.select do |i|
            token = words[i].downcase.gsub(/[^a-z\-]/, "")
            LOCATION_NOISE_TOKENS.include?(token)
          end

          return value if indexes.empty?

          tail = words[(indexes.max + 1)..]
          return value if tail.nil? || tail.empty?

          tail.join(" ")
        end

        def normalize_location(raw)
          location = blank_to_nil(normalize_whitespace(raw))
          return nil if location.nil?

          location = location.sub(/\s*·.*$/, "")
          location = location.gsub(/\bMetropolitan Region\b/i, "et périphérie")
          location = location.sub(/^Greater\s+/i, "")
          location = location.sub(/^F\s+/, "")
          location = location.sub(/^F(?=[A-ZÀ-ÿ])/, "")
          blank_to_nil(normalize_whitespace(location))
        end

        def extract_title(doc, job_posting)
          title = extract_first_text(doc, TITLE_SELECTORS)
          return title unless title.nil? || title.empty?

          title_from_tag = extract_title_from_title_tag(doc)
          return title_from_tag if title_from_tag

          blank_to_nil(normalize_whitespace(job_posting&.[]("title")))
        end

        def extract_company(doc, job_posting)
          company = extract_first_text(doc, COMPANY_SELECTORS)
          return company unless company.nil? || company.empty?

          company_from_tag = extract_company_from_title_tag(doc)
          return company_from_tag if company_from_tag

          org = job_posting&.[]("hiringOrganization")
          org = org.first if org.is_a?(Array)
          blank_to_nil(normalize_whitespace(org.is_a?(Hash) ? org["name"] : nil))
        end

        def extract_title_from_title_tag(doc)
          page_title = normalize_whitespace(doc.at_css("title")&.text)
          return nil if page_title.empty?

          parts = page_title.split("|").map { |part| normalize_whitespace(part) }
          title = parts[0]
          blank_to_nil(title)
        end

        def extract_company_from_title_tag(doc)
          page_title = normalize_whitespace(doc.at_css("title")&.text)
          return nil if page_title.empty?

          parts = page_title.split("|").map { |part| normalize_whitespace(part) }
          return nil if parts.size < 2

          candidate = parts[1]
          return nil if candidate.casecmp("linkedin").zero?

          blank_to_nil(candidate)
        end

        def extract_description_html(doc)
          DESCRIPTION_SELECTORS.each do |selector|
            node = doc.at_css(selector)
            next unless node

            html = node.inner_html&.strip
            return html unless html.nil? || html.empty?
          end

          nil
        end

        def extract_posted_at(doc, job_posting, page_text)
          value = doc.at_css("time[datetime]")&.[]("datetime")
          parsed = parse_time(value)
          return parsed if parsed

          meta_time = doc.at_css("meta[property='article:published_time']")&.[]("content")
          parsed = parse_time(meta_time)
          return parsed if parsed

          parsed = parse_time(job_posting&.[]("datePosted"))
          return parsed if parsed

          listed_at_ms = extract_epoch_millis_from_scripts(doc)
          return Time.zone.at(listed_at_ms / 1000.0) if listed_at_ms

          posted_text = extract_first_text(doc, POSTED_AT_SELECTORS)
          parsed = parse_relative_posted_at(posted_text)
          return parsed if parsed

          parse_relative_posted_at_from_page_text(page_text)
        end

        def extract_salary(doc, page_text, job_posting)
          salary = extract_salary_from_job_posting(job_posting)
          return salary if salary

          salary = extract_salary_from_text(page_text)
          return salary if salary

          {
            salary_min_minor: nil,
            salary_max_minor: nil,
            salary_currency: nil
          }
        end

        def extract_job_posting_json_ld(doc)
          doc.css("script[type='application/ld+json']").each do |script|
            data = JSON.parse(script.text)

            find_job_posting_node(data).tap do |node|
              return node if node
            end
          rescue JSON::ParserError
            next
          end

          nil
        end

        def find_job_posting_node(node)
          case node
          when Array
            node.each do |child|
              match = find_job_posting_node(child)
              return match if match
            end
            nil
          when Hash
            return node if includes_job_posting_type?(node["@type"])

            if node["@graph"].is_a?(Array)
              node["@graph"].each do |child|
                match = find_job_posting_node(child)
                return match if match
              end
            end

            nil
          else
            nil
          end
        end

        def includes_job_posting_type?(type)
          case type
          when String
            type.casecmp("JobPosting").zero?
          when Array
            type.any? { |entry| entry.to_s.casecmp("JobPosting").zero? }
          else
            false
          end
        end

        def extract_salary_from_job_posting(job_posting)
          return nil unless job_posting.is_a?(Hash)

          base = job_posting["baseSalary"]
          entries = base.is_a?(Array) ? base : [ base ]

          entries.each do |entry|
            next unless entry.is_a?(Hash)

            currency = normalize_currency(entry["currency"] || job_posting["salaryCurrency"])
            value = entry["value"]
            value = value.first if value.is_a?(Array)
            value = { "value" => value } unless value.is_a?(Hash)

            min = value["minValue"] || value["value"]
            max = value["maxValue"] || value["value"]
            min_minor = to_minor_amount(min)
            max_minor = to_minor_amount(max)

            next if min_minor.nil? && max_minor.nil?

            return {
              salary_min_minor: min_minor,
              salary_max_minor: max_minor,
              salary_currency: currency
            }
          end

          nil
        end

        def extract_salary_from_text(text)
          return nil if text.nil? || text.empty?

          return nil unless text.match?(/salary|compensation|pay\s*range|remuneration|salaire/i)

          pattern = /(?<currency1>€|\$|£|\bEUR\b|\bUSD\b|\bGBP\b)?\s*(?<min>\d[\d\s.,]*\s*[kK]?)\s*(?:-|to|a|à)\s*(?<currency2>€|\$|£|\bEUR\b|\bUSD\b|\bGBP\b)?\s*(?<max>\d[\d\s.,]*\s*[kK]?)/i
          match = pattern.match(text)
          return nil unless match

          currency = normalize_currency(match[:currency1] || match[:currency2])
          return nil if currency.nil?

          min_minor = parse_amount_to_minor(match[:min])
          max_minor = parse_amount_to_minor(match[:max])
          return nil if min_minor.nil? && max_minor.nil?
          return nil if min_minor && min_minor < 10_000
          return nil if max_minor && max_minor < 10_000

          {
            salary_min_minor: min_minor,
            salary_max_minor: max_minor,
            salary_currency: currency
          }
        end

        def parse_amount_to_minor(value)
          return nil if value.nil?

          raw = value.to_s.strip
          multiplier = raw.match?(/[kK]/) ? 1000 : 1
          numeric = raw.gsub(/[kK]/, "").gsub(/\s/, "")

          numeric = if numeric.include?(",") && numeric.include?(".")
            numeric.delete(",")
          elsif numeric.include?(",")
            numeric.tr(",", ".")
          else
            numeric
          end

          amount = BigDecimal(numeric)
          to_minor_amount(amount * multiplier)
        rescue ArgumentError
          nil
        end

        def to_minor_amount(value)
          return nil if value.nil?

          (BigDecimal(value.to_s) * 100).to_i
        rescue ArgumentError
          nil
        end

        def normalize_currency(value)
          return nil if value.nil?

          raw = value.to_s.strip
          return nil if raw.empty?

          return CURRENCY_BY_SYMBOL[raw] if CURRENCY_BY_SYMBOL.key?(raw)

          normalized = raw.upcase
          return normalized if %w[EUR USD GBP].include?(normalized)

          nil
        end

        def extract_epoch_millis_from_scripts(doc)
          doc.css("script").each do |script|
            content = script.text
            next if content.nil? || content.empty?

            match = content.match(/"listedAt"\s*:\s*(\d{13})/)
            return match[1].to_i if match
          end

          nil
        end

        def parse_time(value)
          return nil if value.nil? || value.empty?

          Time.zone.parse(value)
        rescue ArgumentError
          nil
        end

        def parse_relative_posted_at(value)
          text = normalize_whitespace(value).downcase
          return nil if text.empty?
          return Time.zone.now if text.match?(/\b(today|aujourd'hui|just now|à l'instant)\b/)

          match = text.match(/(?<qty>\d+)\s*(?<unit>minute|minutes|min|hour|hours|hr|day|days|jour|jours|week|weeks|semaine|semaines|month|months|mois)/)
          return nil unless match

          qty = match[:qty].to_i
          case match[:unit]
          when "minute", "minutes", "min"
            qty.minutes.ago
          when "hour", "hours", "hr"
            qty.hours.ago
          when "day", "days", "jour", "jours"
            qty.days.ago
          when "week", "weeks", "semaine", "semaines"
            qty.weeks.ago
          when "month", "months", "mois"
            qty.months.ago
          else
            nil
          end
        end

        def parse_relative_posted_at_from_page_text(value)
          text = normalize_whitespace(value).downcase
          return nil if text.empty?

          explicit = text.match(/(?:reposted|posted)[^\d]{0,40}(?<qty>\d+)\s*(?<unit>minute|minutes|min|hour|hours|hr|day|days|jour|jours|week|weeks|semaine|semaines|month|months|mois)\s+ago/)
          return parse_relative_posted_at(explicit[0]) if explicit

          english = text.match(/(?<qty>\d+)\s*(?<unit>minute|minutes|min|hour|hours|hr|day|days|week|weeks|month|months)\s+ago/)
          return parse_relative_posted_at(english[0]) if english

          french = text.match(/il\s+y\s+a\s+(?<qty>\d+)\s*(?<unit>minute|min|heure|heures|jour|jours|semaine|semaines|mois)/)
          return parse_relative_posted_at(french[0]) if french

          nil
        end

        def map_remote(text)
          return nil if text.nil? || text.empty?

          normalized = text.downcase
          return "hybrid" if normalized.match?(/hybrid|hybride/)
          return "yes" if normalized.match?(/remote|teletravail|télétravail|a distance|à distance/)
          return "no" if normalized.match?(/on\s?-\s?site|on site|sur site|in office|présentiel|presentiel/)

          nil
        end

        def map_employment_type(text)
          return nil if text.nil? || text.empty?

          normalized = text.downcase
          return "PERMANENT" if normalized.match?(/\bcdi\b|permanent/)
          return "FIXED_TERM" if normalized.match?(/\bcdd\b|fixed\s?-?term/)
          return "CONTRACT" if normalized.include?("contract") || normalized.include?("contrat")
          return "FREELANCE" if normalized.include?("freelance") || normalized.include?("indépendant") || normalized.include?("independant")
          return "INTERNSHIP" if normalized.include?("stage") || normalized.include?("internship") || normalized.match?(/\bintern\b/)
          return "APPRENTICESHIP" if normalized.include?("alternance") || normalized.include?("apprenticeship")
          return "TEMPORARY" if normalized.include?("interim") || normalized.include?("intérim") || normalized.include?("temporary")
          return "FULL_TIME" if normalized.include?("temps plein") || normalized.include?("full-time") || normalized.include?("full time")
          return "PART_TIME" if normalized.include?("temps partiel") || normalized.include?("part-time") || normalized.include?("part time")

          nil
        end

        def normalize_whitespace(value)
          return "" if value.nil?

          value.to_s.gsub(/\s+/, " ").strip
        end

        def blank_to_nil(value)
          return nil if value.nil? || value.empty?

          value
        end
      end
    end
  end
end
