# frozen_string_literal: true

module Sourcing
  module Providers
    module CollectiveWork
      module Parsers
        # Maps a Collective.work project to a JobOffer employment_type enum value.
        #
        # The platform only carries the boolean `isPermanentContract` flag:
        #   true  → "PERMANENT" (CDI)
        #   false → "FREELANCE" (default — collective.work is a freelance-mission marketplace)
        #
        # Other contract types (internship, fixed-term, etc.) are not exposed by the SSR
        # payload, so they fall through to FREELANCE rather than being silently mislabeled.
        class Contract
          def self.call(is_permanent_contract:)
            is_permanent_contract == true ? "PERMANENT" : "FREELANCE"
          end
        end
      end
    end
  end
end
