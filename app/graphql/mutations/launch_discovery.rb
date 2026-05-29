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
    field :run_id, GraphQL::Types::ID, null: false,
      description: "ID of the Run created for this discovery. Use to filter offers by run."

    def resolve(keywords: nil, providers: nil)
      run = ::Run.create!(keywords: [], providers: [], work_modes: [])
      Sourcing::LaunchDiscoveryJob.perform_later(keywords: keywords, providers: providers, run_id: run.id)
      { message: "Discovery job enqueued.", run_id: run.id }
    end
  end
end
