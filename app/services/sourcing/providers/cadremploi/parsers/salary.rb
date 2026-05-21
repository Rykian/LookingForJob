# frozen_string_literal: true

module Sourcing
  module Providers
    module Cadremploi
      module Parsers
        # Parses Cadremploi salary into minor units. Formats encountered:
        #   "40 KEUR - 50 KEUR"  → { min: 40000, max: 50000, currency: "EUR" }
        #   "40 KEUR"            → { min: 40000, max: nil,   currency: "EUR" }
        #   JSON-LD baseSalary   → { value: { minValue, maxValue, unitText }, currency }
        #   "Salaire selon profil" → all nils
        class Salary
          SALARY_REGEXP        = /(\d[\d\s]*)\s*KEUR\s*[-–]\s*(\d[\d\s]*)\s*KEUR/i.freeze
          SALARY_SINGLE_REGEXP = /(\d[\d\s]*)\s*KEUR/i.freeze
          UNPRICED_REGEXP      = /selon.*profil|non.*spécifié/i.freeze

          def self.call(doc:, ld:)
            new(doc: doc, ld: ld).call
          end

          def initialize(doc:, ld:)
            @doc = doc
            @ld = ld
          end

          def call
            raw = @ld["baseSalary"] || extract_text
            {
              min: parse_min(raw),
              max: parse_max(raw),
              currency: parse_currency(raw),
            }
          end

          private

          def extract_text
            node = @doc.at_css("[class*='salary']") ||
                   @doc.at_css("[itemprop='baseSalary']") ||
                   @doc.at_css("[class*='remuneration']")
            return node.text.strip if node && node.text.strip.match?(/\d|KEUR|EUR/i)

            info_h2 = @doc.css("h2").find { |h| h.text =~ /information|compl[eé]mentaire/i }
            return nil unless info_h2

            sibling = info_h2.next_element
            5.times do
              break unless sibling

              text = sibling.text.strip
              return text if text.match?(/\d.*KEUR|KEUR.*\d|EUR|salaire/i)

              sibling = sibling.next_element
            end
            nil
          end

          def parse_min(raw)
            if raw.is_a?(Hash)
              return value_to_yearly_minor(quantitative_value(raw)["minValue"], raw)
            end

            return nil unless raw.is_a?(String)
            return nil if raw =~ UNPRICED_REGEXP

            match = raw.match(SALARY_REGEXP) || raw.match(SALARY_SINGLE_REGEXP)
            match[1].gsub(/\s/, "").to_i * 1000 if match
          end

          def parse_max(raw)
            if raw.is_a?(Hash)
              return value_to_yearly_minor(quantitative_value(raw)["maxValue"], raw)
            end

            return nil unless raw.is_a?(String)
            return nil if raw =~ UNPRICED_REGEXP

            match = raw.match(SALARY_REGEXP)
            match[2].gsub(/\s/, "").to_i * 1000 if match
          end

          def parse_currency(raw)
            return raw["currency"].to_s.upcase.presence if raw.is_a?(Hash)

            return nil unless raw.is_a?(String)
            return nil if raw =~ UNPRICED_REGEXP

            "EUR" if raw =~ /KEUR|EUR|€/i
          end

          def quantitative_value(raw)
            value = raw["value"]
            value.is_a?(Hash) ? value : {}
          end

          def value_to_yearly_minor(value, raw)
            amount = value.to_f
            return nil unless amount.positive?

            case quantitative_value(raw)["unitText"].to_s.upcase
            when "MONTH" then (amount * 12).to_i
            else amount.to_i
            end
          end
        end
      end
    end
  end
end
