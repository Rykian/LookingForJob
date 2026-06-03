module Sourcing
  class DeduplicateJob < ApplicationJob
    include Sidekiq::Throttled::Job

    sidekiq_throttle(concurrency: { limit: 1, ttl: 1.hour.to_i })

    def perform
      Sourcing::DeduplicateService.new.call
    end
  end
end
