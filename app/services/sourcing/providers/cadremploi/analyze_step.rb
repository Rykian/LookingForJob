# frozen_string_literal: true

require "nokogiri"
require "json"

module Sourcing
  module Providers
    module Cadremploi
      # Parses the stored HTML from FetchStep (Cadremploi offer detail page).
      # Extraction order: JSON-LD JobPosting > semantic CSS selectors > text heuristics.
      #
      # Selectors verified against live HTML — re-run `rails sourcing:test_analyze source=cadremploi`
      # if the site layout changes.
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 1

        # Cadremploi salary format: "40 KEUR - 50 KEUR" (KEUR = 1 000 EUR).
        # Also: "Salaire selon profil" (treated as nil).
        SALARY_REGEXP = /(\d[\d\s]*)\s*KEUR\s*[-–]\s*(\d[\d\s]*)\s*KEUR/i.freeze
        SALARY_SINGLE_REGEXP = /(\d[\d\s]*)\s*KEUR/i.freeze

        CONTRACT_PATTERNS = [
          [/\bCDI\b/,                                        "PERMANENT"],
          [/\bCDD\b/,                                        "FIXED_TERM"],
          [/full[-_ ]?time|temps plein/i,                     "FULL_TIME"],
          [/part[-_ ]?time|temps partiel/i,                   "PART_TIME"],
          [/alternance|apprentissage|professionnalisation/i, "APPRENTICESHIP"],
          [/\bstage\b/i,                                     "INTERNSHIP"],
          [/int[eé]rim/i,                                    "TEMPORARY"],
          [/lib[eé]rale|portage|freelance/i,                 "FREELANCE"],
          [/contractuel/i,                                   "FIXED_TERM"],
        ].freeze

        LOCATION_MODE_PATTERNS = [
          [/t[eé]l[eé]travail total|full.?remote|100.*remote/i,   "remote"],
          [/hybride|t[eé]l[eé]travail partiel|quelques jours/i,   "hybrid"],
          [/sur site|pr[eé]sentiel|on[- ]?site/i,                 "on-site"],
        ].freeze

        def call(input)
          html = input[:html_content] || input[:html] || ""
          doc  = Nokogiri::HTML(html)
          ld   = extract_json_ld(doc)

          title           = ld["title"] || text_at(doc, "h1")
          company         = ld.dig("hiringOrganization", "name") || extract_company(doc)
          city            = parse_city(ld.dig("jobLocation", "address", "addressLocality") || extract_city(doc))
          employment_type = normalize_contract(ld["employmentType"] || extract_contract_text(doc))
          salary_node     = ld["baseSalary"]
          salary_min      = parse_salary_min(salary_node || extract_salary_text(doc))
          salary_max      = parse_salary_max(salary_node || extract_salary_text(doc))
          salary_currency = parse_salary_currency(salary_node || extract_salary_text(doc))
          location_mode   = detect_location_mode(doc, ld)
          posted_at       = parse_posted_at(ld["datePosted"] || extract_posted_text(doc))
          description_html = clean_attributes(extract_description_html(doc) || ld["description"])

          {
            title:,
            company:,
            city:,
            employment_type:,
            salary_min_minor: salary_min,
            salary_max_minor: salary_max,
            salary_currency:,
            location_mode:,
            posted_at:,
            description_html:,
          }
        end

        private

        # --- JSON-LD ---

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

        # --- Title / Company ---

        def extract_company(doc)
          # Cadremploi shows company in the publisher section "Qui a publié cette offre ?"
          # The company name is typically in an h3 or strong inside that section.
          node = doc.at_css("h3") ||
                 doc.at_css("[class*='company-name']") ||
                 doc.at_css("[class*='recruiter']")
          node&.text&.strip&.presence
        end

        # --- City ---

        def extract_city(doc)
          node = doc.at_css("[itemprop='addressLocality']") ||
                 doc.at_css("[class*='location']") ||
                 doc.at_css("[class*='city']") ||
                 doc.at_css("[class*='localisation']")
          node&.text&.strip&.presence
        end

        def parse_city(raw)
          return nil if raw.nil? || raw.strip.empty?

          # If Cadremploi returns "75 - Paris" like France Travail, strip the prefix.
          raw.sub(/\A\d+\s*[-–]\s*/, "").strip.presence
        end

        # --- Contract type ---

        def extract_contract_text(doc)
          node = doc.at_css("[class*='contract-type']") ||
                 doc.at_css("[class*='contract']") ||
                 doc.at_css("[class*='type-contrat']") ||
                 doc.at_css("[itemprop='employmentType']")
          raw = node&.text&.strip&.presence
          return raw if raw

          # Fallback: scan visible page text for known contract keywords near the title.
          title_node = doc.at_css("h1")
          return nil unless title_node

          # Walk immediate following siblings up to 5 nodes looking for a contract hint.
          sibling = title_node.next_element
          5.times do
            break unless sibling
            CONTRACT_PATTERNS.each do |pattern, _|
              return sibling.text.strip if sibling.text =~ pattern
            end
            sibling = sibling.next_element
          end
          nil
        end

        def normalize_contract(raw)
          return nil if raw.nil? || raw.empty?

          CONTRACT_PATTERNS.each { |pattern, value| return value if raw =~ pattern }
          nil
        end

        # --- Salary ---

        def extract_salary_text(doc)
          # Look inside "Informations complémentaires" section or known salary selectors.
          node = doc.at_css("[class*='salary']") ||
                 doc.at_css("[itemprop='baseSalary']") ||
                 doc.at_css("[class*='remuneration']")
          return node.text.strip if node && node.text.strip.match?(/\d|KEUR|EUR/i)

          # Fallback: find "Informations complémentaires" h2 and read following content.
          info_h2 = doc.css("h2").find { |h| h.text =~ /information|compl[eé]mentaire/i }
          return nil unless info_h2

          sibling = info_h2.next_element
          5.times do
            break unless sibling
            text = sibling.text.strip
            return text if text.match?(/\d.*KEUR|KEUR.*\d|EUR|salaire/i)
            sibling = sibling.next_element
          end
          nil
        end

        def parse_salary_min(raw)
          if raw.is_a?(Hash)
            value = salary_quantitative_value(raw)["minValue"]
            return value_to_yearly_minor(value, raw)
          end

          return nil unless raw.is_a?(String)
          return nil if raw =~ /selon.*profil|non.*spécifié/i

          if raw =~ SALARY_REGEXP
            $1.gsub(/\s/, "").to_i * 1000
          elsif raw =~ SALARY_SINGLE_REGEXP
            $1.gsub(/\s/, "").to_i * 1000
          end
        end

        def parse_salary_max(raw)
          if raw.is_a?(Hash)
            value = salary_quantitative_value(raw)["maxValue"]
            return value_to_yearly_minor(value, raw)
          end

          return nil unless raw.is_a?(String)
          return nil if raw =~ /selon.*profil|non.*spécifié/i

          if raw =~ SALARY_REGEXP
            $2.gsub(/\s/, "").to_i * 1000
          end
        end

        def parse_salary_currency(raw)
          return raw["currency"].to_s.upcase.presence if raw.is_a?(Hash)

          return nil unless raw.is_a?(String)
          return nil if raw =~ /selon.*profil|non.*spécifié/i
          return "EUR" if raw =~ /KEUR|EUR|€/i

          nil
        end

        def salary_quantitative_value(raw)
          value = raw["value"]
          return value if value.is_a?(Hash)

          {}
        end

        def value_to_yearly_minor(value, raw)
          amount = value.to_f
          return nil unless amount.positive?

          unit_text = salary_quantitative_value(raw)["unitText"].to_s.upcase
          case unit_text
          when "MONTH"
            (amount * 12).to_i
          else
            amount.to_i
          end
        end

        # --- Location mode ---

        def detect_location_mode(doc, ld)
          # Try JSON-LD jobLocationType first.
          if (type = ld["jobLocationType"].to_s)
            return "remote" if type =~ /TELECOMMUTE/i
          end

          # Scan visible text for location-mode keywords.
          # Priority: title-area metadata tags, then description.
          text_sources = [
            doc.at_css("[class*='remote']")&.text,
            doc.at_css("[class*='teletravail']")&.text,
            doc.text,
          ].compact.reject(&:empty?)

          text_sources.each do |text|
            LOCATION_MODE_PATTERNS.each do |pattern, value|
              return value if text =~ pattern
            end
          end
          nil
        end

        # --- Posted date ---

        def extract_posted_text(doc)
          node = doc.at_css("[class*='date']") ||
                 doc.at_css("[class*='published']") ||
                 doc.at_css("[class*='publi']") ||
                 doc.at_css("[itemprop='datePosted']")
          node&.text&.strip&.presence
        end

        def parse_posted_at(raw)
          return nil if raw.nil? || raw.empty?

          # ISO 8601 from JSON-LD
          return raw if raw =~ /\A\d{4}-\d{2}-\d{2}/

          text = raw.strip
          if text =~ /il\s*y\s*a\s*(\d+)\s*heure/i
            (Time.now - $1.to_i * 3600).iso8601
          elsif text =~ /il\s*y\s*a\s*(\d+)\s*jour/i
            (Time.now - $1.to_i * 86_400).iso8601
          elsif text =~ /moins\s*de\s*24\s*h/i
            Time.now.iso8601
          elsif text =~ /hier/i
            (Time.now - 86_400).iso8601
          else
            nil
          end
        end

        # --- Description ---

        def extract_description_html(doc)
          # Cadremploi detail pages expose the main sections in dedicated containers.
          # Prefer those exact blocks to keep output concise and stable.
          section_nodes = doc.css("#job-description div, #job-profile div")
          if section_nodes.any?
            html = section_nodes.map { |node| node.to_html.strip }.reject(&:empty?).join("\n")
            return clean_attributes(html) unless html.empty?
          end

          # Try known container selectors first (most reliable if present).
          [
            "[id*='annonce']",
            "[class*='job-description']",
            "[class*='offer-description']",
            "[class*='annonce-body']",
          ].each do |selector|
            node = doc.at_css(selector)
            result = node.inner_html.strip if node && !node.inner_html.strip.empty?
            return clean_attributes(result) if result
          end

          # Fallback: collect the "missions" and "profil" h2 sections.
          extract_h2_sections(doc, /missions|poste/i, /profil|requis|id[eé]al/i)
        end

        # Extracts HTML from zero or more h2 sections whose text matches given patterns.
        # Returns nil when nothing matched.
        def extract_h2_sections(doc, *patterns)
          parts = []
          doc.css("h2").each do |h2|
            next unless patterns.any? { |pat| h2.text =~ pat }

            html_fragments = [h2.to_s]
            node = h2.next_element
            while node && node.name != "h2"
              html_fragments << node.to_s
              node = node.next_element
            end
            parts << html_fragments.join
          end
          result = parts.empty? ? nil : parts.join("\n")
          result ? clean_attributes(result) : nil
        end

        # --- Utility ---

        def text_at(doc, selector)
          doc.at_css(selector)&.text&.strip&.presence
        end
      end
    end
  end
end
