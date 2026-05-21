# frozen_string_literal: true

module Sourcing
  module Providers
    module Cadremploi
      module Parsers
        class LocationMode
          PATTERNS = [
            [/t[eé]l[eé]travail total|full.?remote|100.*remote/i,   "remote"],
            [/hybride|t[eé]l[eé]travail partiel|quelques jours/i,   "hybrid"],
            [/sur site|pr[eé]sentiel|on[- ]?site/i,                 "on-site"],
          ].freeze

          def self.call(doc:, ld:)
            return "remote" if ld["jobLocationType"].to_s =~ /TELECOMMUTE/i

            text_sources = [
              doc.at_css("[class*='remote']")&.text,
              doc.at_css("[class*='teletravail']")&.text,
              doc.text,
            ].compact.reject(&:empty?)

            text_sources.each do |text|
              PATTERNS.each do |pattern, value|
                return value if text =~ pattern
              end
            end
            nil
          end
        end
      end
    end
  end
end
