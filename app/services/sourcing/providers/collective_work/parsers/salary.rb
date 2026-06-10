# frozen_string_literal: true

module Sourcing
  module Providers
    module CollectiveWork
      module Parsers
        # Parses Collective.work `budgetBrief` into yearly EUR amounts.
        #
        # Permanent contracts express budgetBrief as an annual range or single amount in
        # whole euros — "70 000 € - 85 000 €", "75000€", "45k€+ (Annuel)" — which is what
        # the pipeline expects (whole units per Cadremploi/WeLoveDevs convention).
        #
        # Freelance contracts express budgetBrief as a daily rate ("550€/jour", "450-515",
        # "400/500€") on a totally different scale. Treating those as annual would corrupt
        # downstream scoring/filters, so this parser deliberately returns blank for
        # non-permanent contracts and lets the freelance daily-rate channel be added later.
        class Salary
          # Captures one amount and an optional `k` suffix. Examples that match:
          #   "70 000" (→ 70_000), "75000" (→ 75_000), "45" with k-suffix (→ 45_000).
          # The pattern uses \p{Space} to tolerate both ASCII and narrow non-breaking
          # spaces, which collective.work emits inside French thousands separators.
          AMOUNT_REGEXP = /(\d[\d\p{Space}]*\d|\d)\s*(k)?/i.freeze
          # Permanent annual budgets on collective.work are always >= 20k. Smaller values
          # are freelance daily rates that slipped into a permanent contract by mistake.
          MIN_PLAUSIBLE_ANNUAL = 20_000

          def self.call(budget_brief:, is_permanent_contract:)
            blank = { min: nil, max: nil, currency: nil }
            return blank unless is_permanent_contract

            text = budget_brief.to_s.strip
            return blank if text.empty?

            captures = text.scan(AMOUNT_REGEXP).filter_map do |digits, k_suffix|
              value = digits.to_s.gsub(/\p{Space}/, "").to_i
              next nil if value.zero?

              [value, k_suffix.to_s.casecmp?("k")]
            end
            return blank if captures.empty?

            # "55-75k" — k applies to every amount in the range, not only the trailing one.
            any_k = captures.any? { |_, has_k| has_k }
            amounts = captures.map do |value, has_k|
              has_k || (any_k && value < 1_000) ? value * 1_000 : value
            end

            min = amounts.first
            max = amounts.length >= 2 ? amounts[1] : nil
            return blank unless min >= MIN_PLAUSIBLE_ANNUAL

            { min: min, max: max, currency: "EUR" }
          end
        end
      end
    end
  end
end
