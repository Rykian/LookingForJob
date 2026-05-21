# frozen_string_literal: true

module Sourcing
  module Providers
    module Hellowork
      module Parsers
        class Salary
          RANGE_REGEXP  = /(\d[\d\s]+)\s*[-–]\s*(\d[\d\s]+)\s*[€$£]/.freeze
          SINGLE_REGEXP = /(\d[\d\s]+)\s*[€$£]/.freeze

          def self.call(raw)
            { min: parse_min(raw), max: parse_max(raw), currency: parse_currency(raw) }
          end

          def self.parse_min(raw)
            return parse_value(raw, key: "minValue") if raw.is_a?(Hash)

            text = Text.normalize(raw)
            return nil if text.nil?

            if (match = text.match(RANGE_REGEXP))
              to_minor(match[1])
            elsif (match = text.match(SINGLE_REGEXP))
              to_minor(match[1])
            end
          end

          def self.parse_max(raw)
            return parse_value(raw, key: "maxValue") if raw.is_a?(Hash)

            text = Text.normalize(raw)
            return nil if text.nil?

            match = text.match(RANGE_REGEXP)
            match ? to_minor(match[2]) : nil
          end

          def self.parse_currency(raw)
            return raw["currency"].to_s.upcase.presence if raw.is_a?(Hash)

            text = Text.normalize(raw)
            return nil if text.nil?
            return "EUR" if text.match?(/€|eur/i)
            return "USD" if text.match?(/\$/)
            return "GBP" if text.match?(/£|gbp/i)

            nil
          end

          def self.parse_value(raw, key:)
            value = raw.dig("value", key)
            return nil unless value

            amount = value.to_f
            return nil unless amount.positive?

            unit_text = raw.dig("value", "unitText").to_s.upcase
            (unit_text == "MONTH" ? amount * 12 : amount).to_i
          end

          def self.to_minor(raw)
            digits = raw.to_s.gsub(/[^\d]/, "")
            digits.empty? ? nil : digits.to_i
          end
        end
      end
    end
  end
end
