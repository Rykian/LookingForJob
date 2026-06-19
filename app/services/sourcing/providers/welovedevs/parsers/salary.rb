# frozen_string_literal: true

module Sourcing
  module Providers
    module Welovedevs
      module Parsers
        # Maps a WeLoveDevs `details.salary` object to the pipeline's annual convention.
        #
        # WeLoveDevs expresses salary in thousands (e.g. `{min: 75, max: 90}` = 75k–90k),
        # so amounts are scaled ×1000 to whole units (the convention shared with
        # Free-Work / Collective.work — whole units, not cents). Only the yearly channel
        # is read; monthly/other recurrences are on a different scale and would corrupt
        # downstream scoring, so they are left nil. Currency "€" normalizes to "EUR".
        class Salary
          SCALE = 1_000

          def self.call(salary:)
            blank = { min: nil, max: nil, currency: nil }
            return blank unless salary.is_a?(Hash)
            return blank unless salary["recurrence"].to_s == "year"

            min = scaled(salary["min"])
            max = scaled(salary["max"])
            return blank if min.nil? && max.nil?

            { min: min || max, max: max, currency: currency(salary["currency"]) || "EUR" }
          end

          def self.scaled(value)
            return nil unless value.is_a?(Numeric) && value.positive?

            (value * SCALE).to_i
          end
          private_class_method :scaled

          def self.currency(raw)
            return "EUR" if raw.to_s.strip == "€"

            raw.to_s.strip.upcase.presence
          end
          private_class_method :currency
        end
      end
    end
  end
end
