module Sourcing
  class ScoringJob < ApplicationJob
    def perform(url_hash:)
      offer = JobOffer.find_by(url_hash: url_hash)
      return unless offer
      profile = Sourcing::ScoringProfile.load
      score, breakdown = Sourcing::ScoreStep.call(offer: offer, profile: profile)
      offer.update!(
        score: score,
        score_breakdown: breakdown,
        scored_at: Time.current
      )
    rescue => e
      Rails.logger.error("ScoringJob failed for #{url_hash}: #{e.message}")
      raise
    end
  end
end
