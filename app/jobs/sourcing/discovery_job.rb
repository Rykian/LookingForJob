require "digest"

module Sourcing
  class DiscoveryJob < ApplicationJob
    include ActiveJob::Continuable

    # ActiveJob::Continuable's around_perform callback causes Ruby 3+ to receive
    # deserialized kwargs as a positional hash rather than keyword args when the
    # job is executed via Sidekiq. Accept both forms explicitly.
    def perform(*pos_args, source: nil, keyword: nil, work_mode: nil, force: false)
      if (hash = pos_args.first).is_a?(Hash)
        source    = hash[:source]
        keyword   = hash[:keyword]
        work_mode = hash[:work_mode]
        force     = hash.fetch(:force, false)
      end

      input = { source:, keyword:, work_mode:, force: }

      @provider = Sourcing::Providers.registry.fetch(source)
      @discovery_step = @provider.discovery_step
      @playwright_runtime = @discovery_step.initialize_playwright(input: input)

      step :crawl do |job_step|
        page = Integer(job_step.cursor || input.fetch(:page, 1))

        loop do
          result = @discovery_step.crawl_page(
            input: input,
            playwright_runtime: @playwright_runtime,
            page: page
          )
          enqueue_discovered_urls(source: source, discovered_urls: result.fetch(:discovered_urls), force: force)

          break unless result.fetch(:has_next_page, false)

          page += 1
          job_step.advance! from: page
        end
      end

      @discovery_step.close_playwright(playwright_runtime: @playwright_runtime)
    end

    private

    def enqueue_discovered_urls(source:, discovered_urls:, force: false)
      discovered_at = Time.current

      discovered_urls.each do |url|
        offer = upsert_offer_url(source: source, url: url, now: discovered_at)
        Sourcing::PipelineEvents.notify(Sourcing::PipelineEvents::OFFER_DISCOVERED, offer_id: offer.id, force:)
      end
    end

    def upsert_offer_url(source:, url:, now:)
      url_hash = Digest::SHA256.hexdigest(url)
      offer = JobOffer.find_or_initialize_by(url_hash: url_hash)

      offer.source = source
      offer.url = url
      if offer.steps_details&.dig("discovery").nil?
        offer.steps_details = (offer.steps_details || {}).merge(
          "discovery" => {
            "at" => now.iso8601,
            "version" => @discovery_step.class::VERSION,
          }
        )
      end
      offer.last_seen_at = now
      offer.save!

      offer
    rescue ActiveRecord::RecordNotUnique
      existing_offer = JobOffer.find_by!(url_hash: url_hash)
      existing_offer.update!(last_seen_at: now) if existing_offer.last_seen_at.nil? || existing_offer.last_seen_at < now
      existing_offer
    rescue ActiveRecord::RecordInvalid => e
      unless uniqueness_validation_error?(e.record)
        raise
      end

      existing_offer = JobOffer.find_by(url_hash: url_hash) || JobOffer.find_by(url: url)
      raise unless existing_offer

      existing_offer.update!(last_seen_at: now) if existing_offer.last_seen_at.nil? || existing_offer.last_seen_at < now
      existing_offer
    end

    def uniqueness_validation_error?(record)
      record.errors.added?(:url, :taken) || record.errors.added?(:url_hash, :taken)
    end
  end
end
