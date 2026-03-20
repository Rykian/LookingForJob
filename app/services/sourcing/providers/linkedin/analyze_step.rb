require "nokogiri"

module Sourcing
  module Providers
    module Linkedin
      class AnalyzeStep < Sourcing::AnalyzeStep
        TITLE_SELECTORS = [
          ".job-details-jobs-unified-top-card__job-title h1",
          "h1.t-24",
          "h1.jobs-unified-top-card__job-title",
          "h1"
        ].freeze

        COMPANY_SELECTORS = [
          ".job-details-jobs-unified-top-card__company-name a",
          ".job-details-jobs-unified-top-card__company-name",
          ".jobs-unified-top-card__company-name a",
          ".jobs-unified-top-card__company-name"
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
          title = extract_first_text(doc, TITLE_SELECTORS)
          company = extract_first_text(doc, COMPANY_SELECTORS)
          page_text = normalize_whitespace(doc.text)

          {
            title: title,
            company: company,
            remote: map_remote(page_text),
            employment_type: map_employment_type(page_text),
            description_html: extract_description_html(doc),
            salary_min_minor: nil,
            salary_max_minor: nil,
            salary_currency: nil,
            posted_at: extract_posted_at(doc)
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

        def extract_description_html(doc)
          DESCRIPTION_SELECTORS.each do |selector|
            node = doc.at_css(selector)
            next unless node

            html = node.inner_html&.strip
            return html unless html.nil? || html.empty?
          end

          nil
        end

        def extract_posted_at(doc)
          value = doc.at_css("time[datetime]")&.[]("datetime")
          return nil if value.nil? || value.empty?

          Time.zone.parse(value)
        rescue ArgumentError
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
      end
    end
  end
end
