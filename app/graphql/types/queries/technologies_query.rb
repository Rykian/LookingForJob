# frozen_string_literal: true

module Types
  module Queries
    module TechnologiesQuery
      extend ActiveSupport::Concern

      included do
        field :technologies, [String], null: false,
          description: "All technologies from the scoring profile (primary + secondary)."
      end

      def technologies
        profile = Sourcing::ScoringProfile.load
        primary = profile.dig(:technology, :primary) || []
        secondary = profile.dig(:technology, :secondary) || []
        (primary + secondary).uniq
      end
    end
  end
end
