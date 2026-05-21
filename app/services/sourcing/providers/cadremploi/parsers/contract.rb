# frozen_string_literal: true

module Sourcing
  module Providers
    module Cadremploi
      module Parsers
        # Maps free-form contract text or JSON-LD employmentType to a JobOffer
        # employment_type enum value.
        class Contract
          PATTERNS = [
            [/\bCDI\b/,                                        "PERMANENT"],
            [/\bCDD\b/,                                        "FIXED_TERM"],
            [/full[-_ ]?time|temps plein/i,                    "FULL_TIME"],
            [/part[-_ ]?time|temps partiel/i,                  "PART_TIME"],
            [/alternance|apprentissage|professionnalisation/i, "APPRENTICESHIP"],
            [/\bstage\b/i,                                     "INTERNSHIP"],
            [/int[eé]rim/i,                                    "TEMPORARY"],
            [/lib[eé]rale|portage|freelance/i,                 "FREELANCE"],
            [/contractuel/i,                                   "FIXED_TERM"],
          ].freeze

          def self.call(doc:, ld:)
            raw = ld["employmentType"] || extract_text(doc)
            normalize(raw)
          end

          def self.normalize(raw)
            return nil if raw.nil? || raw.empty?

            PATTERNS.each { |pattern, value| return value if raw =~ pattern }
            nil
          end

          def self.extract_text(doc)
            node = doc.at_css("[class*='contract-type']") ||
                   doc.at_css("[class*='contract']") ||
                   doc.at_css("[class*='type-contrat']") ||
                   doc.at_css("[itemprop='employmentType']")
            raw = node&.text&.strip&.presence
            return raw if raw

            # Fallback: scan immediate siblings of h1 for known contract keywords.
            title_node = doc.at_css("h1")
            return nil unless title_node

            sibling = title_node.next_element
            5.times do
              break unless sibling

              PATTERNS.each do |pattern, _|
                return sibling.text.strip if sibling.text =~ pattern
              end
              sibling = sibling.next_element
            end
            nil
          end
        end
      end
    end
  end
end
