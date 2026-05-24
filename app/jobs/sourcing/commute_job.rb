module Sourcing
  class CommuteJob < BaseJob
    include Sourcing::Concerns::OfferJobArguments

    def perform(offer_id, options = {})
      force = extract_force(options)
      offer = find_offer(offer_id)
      return unless offer

      if Sourcing::Pipeline.should_skip?(offer, "commute", force:)
        Sourcing::Pipeline.advance(offer, "commute", force:)
        return
      end

      profile = Sourcing::ScoringProfile.load
      result = Sourcing::CommuteStep.call(offer: offer, profile: profile)

      attrs = {
        commute_city_id: result.commute_city_id,
        steps_details: offer.steps_details.merge("commute" => {
          "at" => Time.current.iso8601,
          "version" => Sourcing::CommuteStep::VERSION,
        }),
      }
      attrs[:city] = result.canonical_city if result.canonical_city.present? && result.canonical_city != offer.city

      offer.update!(attrs)
      Sourcing::Pipeline.advance(offer, "commute", force:)
    end
  end
end
