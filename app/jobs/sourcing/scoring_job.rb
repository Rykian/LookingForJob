module Sourcing
  class ScoringJob < ApplicationJob
    include Sourcing::Concerns::VersionChecking

    def perform(url_hash:, force: false)
      offer = JobOffer.find_by(url_hash: url_hash)
      return unless offer

      current_version = Sourcing::ScoreStep::VERSION

      if should_skip_step?(offer, "score", current_version, force:)
        return
      end

      profile = Sourcing::ScoringProfile.load
      score, breakdown = Sourcing::ScoreStep.call(offer: offer, profile: profile)
      now = Time.current
      offer.update!(
        score: score,
        score_breakdown: breakdown,
        steps_details: offer.steps_details.merge("score" => { "at" => now.iso8601, "version" => current_version })
      )
    rescue => e
      Rails.logger.error("ScoringJob failed for #{url_hash}: #{e.message}")
      raise
    end
  end
end
