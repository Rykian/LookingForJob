module Sourcing
  class OfferAnalyzedSubscriber < BasePipelineSubscriber
    EVENT_NAME = Sourcing::PipelineEvents::OFFER_ANALYZED

    private

    def job_class = Sourcing::EnrichJob
  end
end
