# frozen_string_literal: true

module Sourcing
  module Providers
    module Cadremploi
      module Parsers
        class PostedAt
          def self.call(doc:, ld:)
            raw = ld["datePosted"] || extract_text(doc)
            parse(raw)
          end

          def self.extract_text(doc)
            node = doc.at_css("[class*='date']") ||
                   doc.at_css("[class*='published']") ||
                   doc.at_css("[class*='publi']") ||
                   doc.at_css("[itemprop='datePosted']")
            node&.text&.strip&.presence
          end

          def self.parse(raw)
            return nil if raw.nil? || raw.empty?
            return raw if raw =~ /\A\d{4}-\d{2}-\d{2}/

            text = raw.strip
            case text
            when /il\s*y\s*a\s*(\d+)\s*heure/i
              (Time.now - $1.to_i * 3600).iso8601
            when /il\s*y\s*a\s*(\d+)\s*jour/i
              (Time.now - $1.to_i * 86_400).iso8601
            when /moins\s*de\s*24\s*h/i
              Time.now.iso8601
            when /hier/i
              (Time.now - 86_400).iso8601
            end
          end
        end
      end
    end
  end
end
