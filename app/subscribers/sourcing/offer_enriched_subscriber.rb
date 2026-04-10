module Sourcing
  class OfferEnrichedSubscriber < BasePipelineSubscriber
    EVENT_NAME = Sourcing::PipelineEvents::OFFER_ENRICHED

    private

    def job_class = Sourcing::ScoringJob
  end
end
