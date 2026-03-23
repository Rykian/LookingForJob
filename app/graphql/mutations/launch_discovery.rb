# frozen_string_literal: true

module Mutations
  class LaunchDiscovery < Mutations::BaseMutation
    description "Enqueue a full discovery run across all registered sources and keywords."

    field :message, String, null: false,
      description: "User-facing enqueue confirmation message."

    def resolve
      # Discovery fan-out is handled by LaunchDiscoveryJob based on env configuration.
      Sourcing::LaunchDiscoveryJob.perform_later
      { message: "Discovery job enqueued." }
    end
  end
end
