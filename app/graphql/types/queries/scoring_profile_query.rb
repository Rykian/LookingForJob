# frozen_string_literal: true

module Types
  module Queries
    module ScoringProfileQuery
      extend ActiveSupport::Concern

      included do
        field :scoring_profile, GraphQL::Types::JSON, null: false,
          description: "Current file-backed scoring profile JSON."
      end

      def scoring_profile
        Sourcing::ScoringProfile.load
      end
    end
  end
end
