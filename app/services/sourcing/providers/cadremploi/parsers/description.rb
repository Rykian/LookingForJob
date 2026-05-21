# frozen_string_literal: true

module Sourcing
  module Providers
    module Cadremploi
      module Parsers
        class Description
          CONTAINER_SELECTORS = [
            "[id*='annonce']",
            "[class*='job-description']",
            "[class*='offer-description']",
            "[class*='annonce-body']",
          ].freeze

          SECTION_PATTERNS = [
            /missions|poste/i,
            /profil|requis|id[eé]al/i,
          ].freeze

          def self.call(doc:, ld:)
            html = extract_html(doc) || ld["description"]
            Sourcing::AnalyzeStep.clean_attributes(html)
          end

          def self.extract_html(doc)
            section_nodes = doc.css("#job-description div, #job-profile div")
            if section_nodes.any?
              html = section_nodes.map { |node| node.to_html.strip }.reject(&:empty?).join("\n")
              return html unless html.empty?
            end

            CONTAINER_SELECTORS.each do |selector|
              node = doc.at_css(selector)
              return node.inner_html.strip if node && !node.inner_html.strip.empty?
            end

            extract_h2_sections(doc)
          end

          def self.extract_h2_sections(doc)
            parts = []
            doc.css("h2").each do |h2|
              next unless SECTION_PATTERNS.any? { |pat| h2.text =~ pat }

              fragments = [h2.to_s]
              node = h2.next_element
              while node && node.name != "h2"
                fragments << node.to_s
                node = node.next_element
              end
              parts << fragments.join
            end
            parts.empty? ? nil : parts.join("\n")
          end
        end
      end
    end
  end
end
