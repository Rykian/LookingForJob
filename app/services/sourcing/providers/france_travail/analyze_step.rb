# frozen_string_literal: true

module Sourcing
  module Providers
    module FranceTravail
      # Parses the real HTML returned by FetchStep (France Travail offer detail page).
      # Selectors verified against live HTML on 2026-04-03.
      class AnalyzeStep < Sourcing::AnalyzeStep
        VERSION = 1

        # Maps French/text contract descriptions to pipeline employment_type values.
        CONTRACT_PATTERNS = [
          [/\bCDI\b/,                                       "PERMANENT"],
          [/\bCDD\b/,                                       "FIXED_TERM"],
          [/int[eé]rim|mission intérimaire/i,               "TEMPORARY"],
          [/alternance|apprentissage|professionnalisation/i, "APPRENTICESHIP"],
          [/\bstage\b/i,                                    "INTERNSHIP"],
          [/lib[eé]rale|portage salarial|freelance/i,       "FREELANCE"],
          [/saisonni/i,                                     "FIXED_TERM"],
        ].freeze

        def call(input)
          html = input[:html_content] || input[:html] || ""
          doc  = Nokogiri::HTML(html)
          description_html = extract_description_html(doc)

          {
            title:            extract_attr(doc, "span[itemprop='title']"),
            company:          extract_attr(doc, "[itemprop='hiringOrganization'] [itemprop='name']", attr: "content"),
            city:             parse_city(extract_attr(doc, "p[itemprop='jobLocation'] [itemprop='name']")),
            employment_type:  parse_contract(extract_dl_field(doc, "Type de contrat")),
            salary_min_minor: parse_salary_schema(doc, "minValue"),
            salary_max_minor: parse_salary_schema(doc, "maxValue"),
            salary_currency:  extract_attr(doc, "[itemprop='baseSalary'] [itemprop='currency']", attr: "content"),
            location_mode:    detect_location_mode(
              conditions_text: extract_dl_field(doc, "Conditions de travail"),
              description_text: html_to_text(description_html)
            ),
            posted_at:        parse_posted_at(extract_attr(doc, "span[itemprop='datePosted']", attr: "content")),
            description_html: description_html,
          }
        end

        private

        # Returns node text, or nil if blank.
        def extract_attr(doc, selector, attr: nil)
          node = doc.at_css(selector)
          return nil unless node

          value = attr ? node[attr] : node.text
          value&.strip&.then { |v| v.empty? ? nil : v }
        end

        # Walks dl.icon-group and returns the dd text after a dt matching +title_text+.
        def extract_dl_field(doc, title_text)
          doc.css("dl.icon-group dt").each do |dt|
            next unless dt.text =~ /#{Regexp.escape(title_text)}/i

            dd = dt.next_element
            text = dd&.text&.strip
            return text unless text.nil? || text.empty?
          end
          nil
        end

        # "63 - Clermont-Ferrand" → "Clermont-Ferrand"
        # "75 - PARIS 01" → "Paris 01"
        def parse_city(raw)
          return nil if raw.nil? || raw.empty?

          name = raw.sub(/\A\d+\s*-\s*/, "").strip
          return nil if name.empty?

          name.split(/\s+/).map(&:capitalize).join(" ")
        end

        # Matches the first word(s) of the dt dd text against known patterns.
        # "CDI\nContrat travail" → first line "CDI"
        def parse_contract(raw)
          return nil if raw.nil?

          # Use only the first line (e.g. drop "Contrat travail" sub-label)
          text = raw.lines.first&.strip.to_s
          CONTRACT_PATTERNS.each { |pattern, value| return value if text =~ pattern }
          nil
        end

        # France Travail embeds schema.org microdata for salary with numeric content attrs.
        # unit_text: "YEAR" → use as-is; "MONTH" → ×12; else nil.
        def parse_salary_schema(doc, prop)
          node = doc.at_css("[itemprop='baseSalary'] [itemprop='#{prop}']")
          return nil unless node

          value = node["content"]&.to_f&.to_i
          return nil unless value&.positive?

          unit = doc.at_css("[itemprop='baseSalary'] [itemprop='unitText']")&.[]("content")
          case unit
          when "YEAR"  then value
          when "MONTH" then value * 12
          else nil
          end
        end

        # "Possibilité de télétravail" → hybrid
        # "Télétravail total" / "100% télétravail" → remote
        REMOTE_PATTERN = /t[eé]l[eé]travail (?:total|complet|int[eé]gral)|100\s*%\s*t[eé]l[eé]|full[- ]?remote/i
        HYBRID_PATTERN = /t[eé]l[eé]travail|hybride?/i
        ONSITE_PATTERN = /pr[eé]sentiel|sur site|site client|pas de t[eé]l[eé]travail|aucun t[eé]l[eé]travail/i

        def detect_location_mode(conditions_text:, description_text:)
          text = [conditions_text, description_text].compact.join(" ").strip
          return nil if text.empty?
          return "remote" if text =~ REMOTE_PATTERN
          return "hybrid" if text =~ HYBRID_PATTERN
          return "on-site" if text =~ ONSITE_PATTERN

          # On FranceTravail, missing telework hints usually imply on-site work.
          "on-site"
        end

        # "2026-04-03" → ISO8601 timestamp
        def parse_posted_at(raw)
          return nil if raw.nil? || raw.empty?
          Date.parse(raw).to_time.iso8601
        rescue ArgumentError, TypeError
          nil
        end

        # Extract the minimal description HTML fragment.
        def extract_description_html(doc)
          node = doc.at_css("[itemprop='description']")
          return nil unless node

          html = node.inner_html.strip
          html.empty? ? nil : clean_attributes(html)
        end

        def html_to_text(html)
          return nil if html.nil? || html.empty?

          text = Nokogiri::HTML.fragment(html).text.strip
          text.empty? ? nil : text
        end
      end
    end
  end
end
