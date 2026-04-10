# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :launch_discovery, mutation: Mutations::LaunchDiscovery,
      description: "Enqueue discovery jobs for all configured providers/keywords/modes."
    field :recompute_offer_scores, mutation: Mutations::RecomputeOfferScores,
      description: "Enqueue score recomputation for every stored offer."
    field :update_scoring_profile, mutation: Mutations::UpdateScoringProfile,
      description: "Replace the scoring profile JSON used by scoring jobs."
  end
end
