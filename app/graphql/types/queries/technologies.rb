# frozen_string_literal: true

module Types
  module Queries
    module Technologies
      extend ActiveSupport::Concern

      included do
        field :technologies, [String], null: false,
          description: "Technologies from the scoring profile, optionally "\
            "extended with common discovered technologies. If no arguments are"\
            " provided, all technologies will be included." do
          argument :include_primary, GraphQL::Types::Boolean, required: false,
            default_value: false,
            description: "Whether to include only primary technologies from the scoring profile."
          argument :include_secondary, GraphQL::Types::Boolean, required: false,
            default_value: false,
            description: "Whether to include only secondary technologies from the scoring profile."
          argument :include_common, GraphQL::Types::Boolean, required: false,
            default_value: false,
            description: "Whether to include common technologies from the scoring profile."
        end
      end

      def technologies(include_primary: false, include_secondary: false, include_common: false)
        results = []
        everything = !include_primary && !include_secondary && !include_common

        if include_primary || everything
          scoring = Sourcing::ScoringProfile.load
          results += scoring.dig(:technology, :primary) || []
        end
        if include_secondary || everything
          scoring ||= Sourcing::ScoringProfile.load
          results += scoring.dig(:technology, :secondary) || []
        end
        if include_common || everything
          results += Sourcing::TechnologyStore.read_common_technologies
        end
        results.uniq
      end
    end
  end
end
