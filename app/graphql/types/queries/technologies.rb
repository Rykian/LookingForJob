# frozen_string_literal: true

module Types
  module Queries
    module Technologies
      extend ActiveSupport::Concern

      included do
        field :technologies, [String], null: false,
          description: "Primary technologies from the scoring profile."
      end

      def technologies
        profile = Sourcing::ScoringProfile.load
        profile.dig(:technology, :primary) || []
      end
    end
  end
end
