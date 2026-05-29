# frozen_string_literal: true

module Types
  module Queries
    module Runs
      extend ActiveSupport::Concern

      included do
        field :runs, [Types::RunType], null: false,
          description: "List all runs ordered by most recent first."
      end

      def runs
        ::Run.order(created_at: :desc).all
      end
    end
  end
end
