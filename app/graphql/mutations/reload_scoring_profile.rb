# frozen_string_literal: true

module Mutations
  class ReloadScoringProfile < Mutations::BaseMutation
    description "Drop the in-memory scoring profile cache and re-read it from disk."

    field :profile, GraphQL::Types::JSON, null: false,
      description: "The freshly-loaded profile payload."

    def resolve
      { profile: Sourcing::ScoringProfile.reload! }
    rescue RuntimeError => e
      raise GraphQL::ExecutionError, e.message
    end
  end
end
