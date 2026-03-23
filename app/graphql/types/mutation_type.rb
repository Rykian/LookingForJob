# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :launch_discovery, mutation: Mutations::LaunchDiscovery
    field :update_scoring_profile, mutation: Mutations::UpdateScoringProfile
  end
end

