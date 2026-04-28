module Sourcing
  class BaseJob < ApplicationJob
    STATUS_TRIGGER_THROTTLE_SECONDS = 1
    STATUS_TRIGGER_LOCK_KEY = "sourcing_status:trigger:lock"

    around_perform do |_job, block|
      block.call
    ensure
      broadcast_sourcing_status
    end

    private

    def broadcast_sourcing_status
      return unless should_trigger_sourcing_status?

      status = Sourcing::JobStatusService.call
      LookingForJobSchema.subscriptions.trigger(:sourcing_status, {}, status)
    rescue StandardError => e
      Rails.logger.warn("sourcing_status trigger failed: #{e.class} #{e.message}")
    end

    def should_trigger_sourcing_status?
      Sidekiq.redis do |redis|
        # Returns true if the key was set, meaning we should trigger; false if the key already exists, meaning we should skip.
        redis.set(
          STATUS_TRIGGER_LOCK_KEY,
          Process.clock_gettime(Process::CLOCK_MONOTONIC).to_s,
          nx: true,
          ex: STATUS_TRIGGER_THROTTLE_SECONDS
        )
      end
    rescue StandardError => e
      Rails.logger.warn("sourcing_status throttle check failed: #{e.class} #{e.message}")
      true
    end
  end
end
