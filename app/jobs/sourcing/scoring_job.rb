module Sourcing
  class ScoringJob < ApplicationJob
    def perform(url_hash:)
      offer = JobOffer.find_by(url_hash: url_hash)
      return unless offer
      profile = Sourcing::ScoringProfile.load
      score, breakdown = Sourcing::ScoreStep.call(offer: offer, profile: profile)
      now = Time.current
      offer.update!(
        score: score,
        score_breakdown: breakdown,
        steps_details: offer.steps_details.merge("score" => { "at" => now.iso8601, "version" => 1 })
      )
    rescue => e
      Rails.logger.error("ScoringJob failed for #{url_hash}: #{e.message}")
      raise
    end
  end
end
