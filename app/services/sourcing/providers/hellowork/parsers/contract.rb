# frozen_string_literal: true

module Sourcing
  module Providers
    module Hellowork
      module Parsers
        class Contract
          PATTERNS = [
            [/\bCDI\b/i,                                       "PERMANENT"],
            [/\bCDD\b/i,                                       "FIXED_TERM"],
            [/alternance|apprentissage|professionnalisation/i, "APPRENTICESHIP"],
            [/\bstage\b/i,                                     "INTERNSHIP"],
            [/freelance|ind[ée]pendant/i,                      "FREELANCE"],
            [/int[ée]rim|temporaire/i,                         "TEMPORARY"],
            [/full[-_ ]?time|temps plein/i,                    "FULL_TIME"],
            [/part[-_ ]?time|temps partiel/i,                  "PART_TIME"],
          ].freeze

          def self.call(raw)
            value = Text.normalize(raw)
            return nil if value.nil? || value.empty?

            PATTERNS.each do |pattern, normalized|
              return normalized if value.match?(pattern)
            end

            nil
          end
        end
      end
    end
  end
end
