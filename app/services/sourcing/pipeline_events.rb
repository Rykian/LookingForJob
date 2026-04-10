module Sourcing
  module PipelineEvents
    OFFER_DISCOVERED = "sourcing.offer_discovered".freeze
    OFFER_FETCHED = "sourcing.offer_fetched".freeze
    OFFER_ANALYZED = "sourcing.offer_analyzed".freeze
    OFFER_ENRICHED = "sourcing.offer_enriched".freeze

    module_function

    def notify(name, offer_id:, force: false)
      Rails.event.notify(name, offer_id:, force:)
    end
  end
end
