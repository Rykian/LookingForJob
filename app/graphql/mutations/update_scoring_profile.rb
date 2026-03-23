# frozen_string_literal: true

module Mutations
  class UpdateScoringProfile < Mutations::BaseMutation
    description "Overwrite the file-backed scoring profile with the provided JSON object."

    argument :profile, GraphQL::Types::JSON, required: true,
      description: "Full scoring profile JSON payload."

    field :profile, GraphQL::Types::JSON, null: false,
      description: "The persisted profile payload after validation."

    def resolve(profile:)
      # Profile arrives as a Hash from GraphQL::Types::JSON.
      Sourcing::ScoringProfile.validate!(profile.deep_stringify_keys)
      json = JSON.pretty_generate(profile.deep_stringify_keys)
      File.write(Sourcing::ScoringProfile::PROFILE_PATH, json)
      { profile: profile }
    rescue RuntimeError => e
      raise GraphQL::ExecutionError, e.message
    end
  end
end
