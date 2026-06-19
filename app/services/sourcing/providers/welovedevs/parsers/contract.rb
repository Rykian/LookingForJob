# frozen_string_literal: true

module Sourcing
  module Providers
    module Welovedevs
      module Parsers
        # Maps a WeLoveDevs `contractTypes` array to a JobOffer employment_type value.
        #
        # An offer may advertise several contract types; the most "permanent-leaning" one
        # wins (PERMANENT priority, matching the other providers) so a CDI tagged alongside
        # an internship is not mislabelled. Unknown types are ignored.
        class Contract
          # WeLoveDevs contractType => JobOffer enum value.
          TYPE_MAP = {
            "permanent"      => "PERMANENT",
            "fixedTerm"      => "FIXED_TERM",
            "apprenticeship" => "APPRENTICESHIP",
            "internship"     => "INTERNSHIP",
            "freelance"      => "FREELANCE",
          }.freeze

          # Specific-to-loose; first match wins.
          PRIORITY = %w[permanent fixedTerm apprenticeship internship freelance].freeze

          def self.call(contract_types:)
            types = Array(contract_types).map(&:to_s)
            key = PRIORITY.find { |candidate| types.include?(candidate) }
            key && TYPE_MAP[key]
          end
        end
      end
    end
  end
end
