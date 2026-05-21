# frozen_string_literal: true

require "set"

module Sourcing
  module Providers
    module Hellowork
      module Parsers
        class Description
          SECTION_PATTERNS = [
            /d[ée]tail du poste/i,
            /missions? du poste/i,
            /profil recherch/i,
            /avantages?/i,
            /infos? compl[ée]mentaires?/i,
            /bienvenue chez/i,
            /comp[ée]tences?/i,
            /stack technique/i,
          ].freeze

          def self.call(doc:, ld:)
            description = extract_sections(doc) || ld["description"]
            cleaned = strip_non_content_nodes(description)
            cleaned = Sourcing::AnalyzeStep.clean_attributes(cleaned)
            cleaned.nil? || cleaned.empty? ? nil : cleaned
          end

          def self.strip_non_content_nodes(raw_html)
            return raw_html if raw_html.nil? || raw_html.empty?

            fragment = Nokogiri::HTML.fragment(raw_html)
            fragment.css("script,style,nav,footer,aside,button,svg,use").remove
            fragment.to_html
          end

          def self.extract_sections(doc)
            blocks = []
            seen_texts = Set.new

            doc.css("section, details").each do |container|
              heading = extract_section_heading(container)
              next unless include_section?(heading)

              block_html = build_section_block(container, heading)
              next if block_html.nil?

              block_text = Text.html_to_text(block_html)
              next if block_text.nil? || seen_texts.include?(block_text)

              blocks << block_html
              seen_texts << block_text
            end

            blocks.concat(extract_h2_sections(doc, seen_texts)) if blocks.empty?

            blocks.empty? ? nil : blocks.join("\n")
          end

          def self.extract_h2_sections(doc, seen_texts)
            blocks = []
            doc.css("h2").each do |h2|
              heading_text = Text.normalize(h2.text)
              next unless include_section?(heading_text)

              fragments = [h2.to_html]
              node = h2.next_element
              while node && node.name != "h2"
                fragments << node.to_html
                node = node.next_element
              end

              block_html = fragments.join
              block_text = Text.html_to_text(block_html)
              next if block_text.nil? || seen_texts.include?(block_text)

              blocks << block_html
              seen_texts << block_text
            end
            blocks
          end

          def self.include_section?(heading)
            heading_text = Text.normalize(heading)
            return false if heading_text.nil?

            SECTION_PATTERNS.any? { |pattern| heading_text.match?(pattern) }
          end

          def self.extract_section_heading(container)
            heading_node = if container.name == "details"
              container.at_css("summary h2 span") || container.at_css("summary h2") || container.at_css("summary")
            else
              container.at_css("h2 span") || container.at_css("h2")
            end

            Text.normalize(heading_node&.text)
          end

          def self.build_section_block(container, heading)
            content_html = extract_section_content_html(container)
            return nil if content_html.nil?

            "<h2>#{heading}</h2>\n#{content_html}"
          end

          def self.extract_section_content_html(container)
            if (expanded_content = container.at_css("[data-truncate-text-target='content']"))
              return expanded_content.to_html
            end

            if container.name == "details"
              content_nodes = container.element_children.reject { |child| child.name == "summary" }
              content_html = content_nodes.map(&:to_html).join("\n")
              return content_html unless content_html.empty?
            end

            content_nodes = container.element_children.reject do |child|
              child.name == "h2" || child.name == "summary"
            end
            content_html = content_nodes.map(&:to_html).join("\n")
            content_html.empty? ? nil : content_html
          end
        end
      end
    end
  end
end
