# frozen_string_literal: true

module Sourcing
  module Providers
    module Welovedevs
      module Parsers
        # Maps a WeLoveDevs offer to a JobOffer employment_type enum value.
        #
        # The JSON-LD employmentType only carries coarse schema.org values (FULL_TIME,
        # PART_TIME, ...) and loses the permanent/freelance distinction, so the templated
        # meta description ("... in Permanent contract") is checked first for the precise
        # contract, falling back to the JSON-LD value.
        class Contract
          # Ordered specific-first; checked against the meta description text.
          TEXT_PATTERNS = [
            [/\bfreelance\b|portage/i,                               "FREELANCE"],
            [/\bpermanent\b|\bCDI\b/i,                               "PERMANENT"],
            [/fixed[-\s]?term|\bCDD\b/i,                             "FIXED_TERM"],
            [/apprenticeship|work[-\s]?study|alternance|apprentissage/i, "APPRENTICESHIP"],
            [/internship|\bintern\b|\bstage\b/i,                     "INTERNSHIP"],
            [/part[-\s]?time|temps partiel/i,                        "PART_TIME"],
            [/full[-\s]?time|temps plein/i,                          "FULL_TIME"],
          ].freeze

          # schema.org employmentType → JobOffer enum value.
          LD_MAP = {
            "FULL_TIME"  => "FULL_TIME",
            "PART_TIME"  => "PART_TIME",
            "CONTRACTOR" => "FREELANCE",
            "TEMPORARY"  => "TEMPORARY",
            "INTERN"     => "INTERNSHIP",
          }.freeze

          def self.call(ld:, text:)
            from_text(text) || from_ld(ld["employmentType"])
          end

          def self.from_text(text)
            return nil if text.to_s.empty?

            TEXT_PATTERNS.each { |pattern, value| return value if text =~ pattern }
            nil
          end

          def self.from_ld(raw)
            value = raw.is_a?(Array) ? raw.first : raw
            return nil if value.nil?

            LD_MAP[value.to_s.strip.upcase]
          end
        end
      end
    end
  end
end
