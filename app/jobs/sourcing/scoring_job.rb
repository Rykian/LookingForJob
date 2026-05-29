module Sourcing
  class ScoringJob < BaseJob
    include Sourcing::Concerns::OfferJobArguments

    def perform(offer_id, options = {})
      force = extract_force(options)
      offer = find_offer(offer_id)
      return unless offer

      return if Sourcing::Pipeline.should_skip?(offer, "score", force:)

      profile = Sourcing::ScoringProfile.load
      score, breakdown = Sourcing::ScoreStep.call(offer: offer, profile: profile)
      now = Time.current
      offer.update!(
        score: score,
        score_breakdown: breakdown,
        steps_details: offer.steps_details.merge("score" => { "at" => now.iso8601, "version" => Sourcing::ScoreStep::VERSION })
      )
    end
  end
end
