# frozen_string_literal: true

module Sourcing
  module Providers
    module FreeWork
      module Parsers
        # Maps Free-Work structured salary fields to the pipeline's annual convention.
        #
        # The API carries two separate channels: `minAnnualSalary`/`maxAnnualSalary`
        # (whole euros, populated for permanent/fixed-term offers) and
        # `minDailySalary`/`maxDailySalary` (freelance daily rate). Daily rates are on a
        # different scale and would corrupt downstream scoring/filters if treated as
        # annual, so only the annual channel is read (same rule as Collective.work).
        class Salary
          def self.call(min_annual:, max_annual:, currency:)
            blank = { min: nil, max: nil, currency: nil }

            min = positive_integer(min_annual)
            max = positive_integer(max_annual)
            return blank if min.nil? && max.nil?

            { min: min || max, max: max, currency: currency.to_s.strip.upcase.presence || "EUR" }
          end

          def self.positive_integer(value)
            integer = value.is_a?(Numeric) ? value.to_i : nil
            integer&.positive? ? integer : nil
          end
          private_class_method :positive_integer
        end
      end
    end
  end
end
