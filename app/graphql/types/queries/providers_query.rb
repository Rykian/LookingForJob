# frozen_string_literal: true

module Types
  module Queries
    module ProvidersQuery
      extend ActiveSupport::Concern

      included do
        field :providers, [Types::ProviderEnum], null: false,
          description: "All available sourcing provider keys."
      end

      def providers
        Sourcing::Providers.registry.sources
      end
    end
  end
end
