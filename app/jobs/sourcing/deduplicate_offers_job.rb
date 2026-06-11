module Sourcing
  class DeduplicateOffersJob < ApplicationJob
    include Sidekiq::Throttled::Job

    sidekiq_throttle(concurrency: { limit: 1, ttl: 1.hour.to_i })

    def perform
      Sourcing::DeduplicateOffersService.new.call
    end
  end
end
