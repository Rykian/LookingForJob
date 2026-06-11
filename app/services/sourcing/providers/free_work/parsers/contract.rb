# frozen_string_literal: true

module Sourcing
  module Providers
    module FreeWork
      module Parsers
        # Maps the Free-Work `contracts[]` array to a JobOffer employment_type enum value.
        #
        # Live API values (verified 2026-06): permanent, contractor, fixed-term,
        # apprenticeship, internship. An offer can accept several contract types at once
        # (e.g. ["contractor", "permanent"]); we report the highest-priority one, with
        # PERMANENT first because the salary convention (annual euros) follows it.
        # Unknown values are skipped rather than silently mislabeled.
        class Contract
          TYPE_MAP = {
            "permanent"      => "PERMANENT",
            "contractor"     => "FREELANCE",
            "fixed-term"     => "FIXED_TERM",
            "apprenticeship" => "APPRENTICESHIP",
            "internship"     => "INTERNSHIP",
          }.freeze

          PRIORITY = %w[PERMANENT FREELANCE FIXED_TERM APPRENTICESHIP INTERNSHIP].freeze

          def self.call(contracts:)
            types = Array(contracts).filter_map { |c| TYPE_MAP[c.to_s.downcase] }
            return nil if types.empty?

            PRIORITY.find { |type| types.include?(type) }
          end
        end
      end
    end
  end
end
