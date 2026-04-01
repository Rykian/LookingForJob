# frozen_string_literal: true

module Types
  class ProviderEnum < Types::BaseEnum
    description "All available sourcing provider keys."

    # Add all provider keys as enum values
    Sourcing::Providers.registry.sources.each do |key|
      value key, value: key, description: "Provider: #{key}"
    end
  end
end
