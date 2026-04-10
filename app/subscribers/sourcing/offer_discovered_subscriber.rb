module Sourcing
  class OfferDiscoveredSubscriber < BasePipelineSubscriber
    EVENT_NAME = Sourcing::PipelineEvents::OFFER_DISCOVERED

    private

    def job_class = Sourcing::FetchJob
  end
end
