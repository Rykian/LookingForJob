# frozen_string_literal: true

module Mutations
  class LaunchDiscovery < Mutations::BaseMutation
    description "Enqueue a full discovery run across all registered sources and keywords."

    argument :keywords, [String], required: false,
      description: "Keywords to discover. Omit to use profile defaults."
    argument :providers, [Types::ProviderEnum], required: false,
      description: "Providers to discover from. Omit to use all registered providers."

    field :message, String, null: false,
      description: "User-facing enqueue confirmation message."

    def resolve(keywords: nil, providers: nil)
      # Discovery fan-out is handled by LaunchDiscoveryJob based on env configuration.
      Sourcing::LaunchDiscoveryJob.perform_later(keywords: keywords, providers: providers)
      { message: "Discovery job enqueued." }
    end
  end
end
