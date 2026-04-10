# frozen_string_literal: true

module Mutations
  class RecomputeOfferScores < Mutations::BaseMutation
    description "Enqueue score recomputation for every stored offer."

    field :message, String, null: false,
      description: "User-facing enqueue confirmation message."
    field :enqueued_count, Integer, null: false,
      description: "Number of scoring jobs enqueued."

    def resolve
      offer_ids = JobOffer.pluck(:id)
      offer_ids.each do |offer_id|
        Sourcing::ScoringJob.perform_later(offer_id)
      end

      {
        message: "Score recomputation enqueued for #{offer_ids.size} offers.",
        enqueued_count: offer_ids.size,
      }
    end
  end
end
