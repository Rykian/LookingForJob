# frozen_string_literal: true

module Sourcing
  module Providers
    module Hellowork
      module Parsers
        class PostedAt
          def self.call(doc:, ld:)
            parse(ld["datePosted"] || extract_from_doc(doc))
          end

          def self.extract_from_doc(doc)
            text = Text.text_at(doc, "[aria-label*='Publi']") || Text.text_at(doc, "*[class*='published']")
            return nil unless text

            date_match = text.match(/(\d{2})\/(\d{2})\/(\d{4})/)
            return nil unless date_match

            "#{date_match[3]}-#{date_match[2]}-#{date_match[1]}"
          end

          def self.parse(raw)
            value = Text.normalize(raw)
            return nil if value.nil?
            return value if value.match?(/\A\d{4}-\d{2}-\d{2}(?:T.*)?\z/)

            nil
          end
        end
      end
    end
  end
end
