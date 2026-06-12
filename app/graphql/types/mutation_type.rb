# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :launch_discovery, mutation: Mutations::LaunchDiscovery,
      description: "Enqueue discovery jobs for all configured providers/keywords/modes."
    field :recompute_offer_scores, mutation: Mutations::RecomputeOfferScores,
      description: "Enqueue score recomputation for every stored offer."
    field :update_scoring_profile, mutation: Mutations::UpdateScoringProfile,
      description: "Replace the scoring profile JSON used by scoring jobs."
    field :reload_scoring_profile, mutation: Mutations::ReloadScoringProfile,
      description: "Reload the scoring profile from disk (drops the in-memory cache)."
    field :set_offer_final_client, mutation: Mutations::SetOfferFinalClient,
      description: "Manually set or clear the final client behind an offer."
    field :add_company_alias, mutation: Mutations::AddCompanyAlias,
      description: "Claim a name as company alias, relinking matching offers (merge)."
    field :remove_company_alias, mutation: Mutations::RemoveCompanyAlias,
      description: "Split an alias into a new company with its matching offers."
    field :rename_company, mutation: Mutations::RenameCompany,
      description: "Update a company's official name."
  end
end
