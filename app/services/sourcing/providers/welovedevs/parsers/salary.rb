# frozen_string_literal: true

module Sourcing
  module Providers
    module Welovedevs
      module Parsers
        # Parses WeLoveDevs salary into yearly amounts.
        #
        # Primary source is the JSON-LD baseSalary MonetaryAmount (always present and
        # already yearly on WeLoveDevs). The templated meta description ("Salaire 45k to
        # 55k") is a text fallback. Amounts follow the pipeline convention (whole units,
        # not cents) used by Cadremploi/Hellowork.
        class Salary
          TEXT_RANGE_REGEXP = /(\d+)\s*k\b.*?(\d+)\s*k\b/i.freeze
          TEXT_SINGLE_REGEXP = /(\d+)\s*k\b/i.freeze

          def self.call(ld:, text:)
            base = ld["baseSalary"]
            return from_ld(base) if base.is_a?(Hash)

            from_text(text)
          end

          def self.from_ld(base)
            value = base["value"].is_a?(Hash) ? base["value"] : {}
            unit = value["unitText"]
            {
              min: to_yearly(value["minValue"], unit),
              max: to_yearly(value["maxValue"], unit),
              currency: base["currency"].to_s.upcase.presence,
            }
          end

          def self.to_yearly(amount, unit)
            value = amount.to_f
            return nil unless value.positive?

            unit.to_s.upcase == "MONTH" ? (value * 12).to_i : value.to_i
          end

          def self.from_text(text)
            blank = { min: nil, max: nil, currency: nil }
            return blank if text.to_s.empty?

            if (match = text.match(TEXT_RANGE_REGEXP))
              { min: match[1].to_i * 1_000, max: match[2].to_i * 1_000, currency: currency_for(text) }
            elsif (match = text.match(TEXT_SINGLE_REGEXP))
              { min: match[1].to_i * 1_000, max: nil, currency: currency_for(text) }
            else
              blank
            end
          end

          def self.currency_for(text)
            "EUR" if text =~ /€|eur/i
          end
        end
      end
    end
  end
end
