# frozen_string_literal: true

module Mutations
  class UpdateScoringProfile < Mutations::BaseMutation
    description "Overwrite the file-backed scoring profile with the provided JSON object."

    argument :profile, GraphQL::Types::JSON, required: true

    field :profile, GraphQL::Types::JSON, null: false

    def resolve(profile:)
      # profile arrives as a Hash from GraphQL::Types::JSON
      Sourcing::ScoringProfile.validate!(profile.deep_stringify_keys)
      json = JSON.pretty_generate(profile.deep_stringify_keys)
      File.write(Sourcing::ScoringProfile::PROFILE_PATH, json)
      { profile: profile }
    rescue RuntimeError => e
      raise GraphQL::ExecutionError, e.message
    end
  end
end
