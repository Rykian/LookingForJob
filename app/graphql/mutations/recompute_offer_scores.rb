# frozen_string_literal: true

module Mutations
  class RecomputeOfferScores < Mutations::BaseMutation
    description "Enqueue score recomputation for every stored offer."

    field :message, String, null: false,
      description: "User-facing enqueue confirmation message."
    field :enqueued_count, Integer, null: false,
      description: "Number of scoring jobs enqueued."

    def resolve
      url_hashes = JobOffer.pluck(:url_hash)
      url_hashes.each do |url_hash|
        Sourcing::ScoringJob.perform_later(url_hash: url_hash)
      end

      {
        message: "Score recomputation enqueued for #{url_hashes.size} offers.",
        enqueued_count: url_hashes.size
      }
    end
  end
end
