# frozen_string_literal: true

module Mutations
  class LaunchDiscovery < Mutations::BaseMutation
    description "Enqueue a full discovery run across all registered sources and keywords."

    field :message, String, null: false

    def resolve
      Sourcing::LaunchDiscoveryJob.perform_later
      { message: "Discovery job enqueued." }
    end
  end
end
