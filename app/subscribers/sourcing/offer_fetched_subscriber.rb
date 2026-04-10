module Sourcing
  class OfferFetchedSubscriber < BasePipelineSubscriber
    EVENT_NAME = Sourcing::PipelineEvents::OFFER_FETCHED

    private

    def job_class = Sourcing::AnalyzeJob
  end
end
