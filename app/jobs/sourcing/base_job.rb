module Sourcing
  class BaseJob < ApplicationJob
    STATUS_TRIGGER_THROTTLE_SECONDS = 1
    STATUS_TRIGGER_LOCK_KEY = "sourcing_status:trigger:lock"

    STEP_NAMES = {
      "Sourcing::DiscoveryJob" => "discovery",
      "Sourcing::FetchJob"     => "fetch",
      "Sourcing::AnalyzeJob"   => "analyze",
      "Sourcing::EnrichJob"    => "enrich",
      "Sourcing::CommuteJob"   => "commute",
      "Sourcing::ScoringJob"   => "score",
      "Sourcing::CompanyJob"   => "company",
    }.freeze

    around_perform do |_job, block|
      block.call
    ensure
      broadcast_sourcing_status
    end

    around_perform do |job, block|
      block.call
    rescue => e
      record_pipeline_error(job, e) if job.send(:pipeline_step_name)
      raise
    end

    private

    def record_pipeline_error(job, error)
      PipelineError.create!(
        job_offer_id: job.send(:pipeline_offer_id),
        run_id: job.send(:pipeline_run_id),
        step: job.send(:pipeline_step_name),
        source: job.send(:pipeline_source),
        step_version: job.send(:pipeline_step_version),
        error_class: error.class.name,
        error_message: error.message,
        arguments: (job.arguments || {}).as_json
      )
    rescue StandardError => e
      Rails.logger.error("Failed to record pipeline error: #{e.class} #{e.message}")
    end

    def pipeline_step_name
      STEP_NAMES[self.class.name]
    end

    def pipeline_offer_id
      first = arguments.first
      first.is_a?(Integer) ? first : nil
    end

    def pipeline_options_hash
      arguments.find { |a| a.is_a?(Hash) } || {}
    end

    def pipeline_source
      @pipeline_source ||= pipeline_options_hash["source"] ||
                          pipeline_options_hash[:source] ||
                          (pipeline_offer_id && JobOffer.where(id: pipeline_offer_id).pick(:source))
    end

    def pipeline_run_id
      pipeline_options_hash["run_id"] || pipeline_options_hash[:run_id]
    end

    def pipeline_step_version
      return nil unless pipeline_source
      provider = Sourcing::Providers.registry.fetch(pipeline_source)
      step_def = Sourcing::Pipeline::STEPS.find { |s| s[:name] == pipeline_step_name }
      step_def&.dig(:version)&.call(provider)
    rescue
      nil
    end

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
