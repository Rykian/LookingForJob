Rails.application.config.to_prepare do
  [
    Sourcing::OfferDiscoveredSubscriber,
    Sourcing::OfferFetchedSubscriber,
    Sourcing::OfferAnalyzedSubscriber,
    Sourcing::OfferEnrichedSubscriber,
  ].each do |subscriber_class|
    Rails.event.unsubscribe(subscriber_class)
    Rails.event.subscribe(subscriber_class.new) do |event|
      event[:name] == subscriber_class::EVENT_NAME
    end
  end
end
