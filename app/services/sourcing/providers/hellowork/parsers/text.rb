# frozen_string_literal: true

module Sourcing
  module Providers
    module Hellowork
      module Parsers
        # Text-normalization helpers shared across hellowork parsers.
        module Text
          module_function

          def normalize(value)
            return nil if value.nil?

            normalized = value.to_s.gsub(" ", " ").gsub(/\s+/, " ").strip
            normalized.empty? ? nil : normalized
          end

          def html_to_text(raw_html)
            value = raw_html.to_s
            return nil if value.empty?

            normalize(Nokogiri::HTML.fragment(value).text)
          end

          def text_at(doc, selector)
            normalize(doc.at_css(selector)&.text)
          end
        end
      end
    end
  end
end
