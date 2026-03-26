require "digest"

module Sourcing
  class DiscoveryJob < ApplicationJob
    include ActiveJob::Continuable

    def perform(source:, keyword:, work_mode:)
      input = {
        source: source,
        keyword: keyword,
        work_mode: work_mode,
      }

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
          enqueue_discovered_urls(source: source, discovered_urls: result.fetch(:discovered_urls))

          break unless result.fetch(:has_next_page, false)

          page += 1
          job_step.advance! from: page
        end
      end

      @discovery_step.close_playwright(playwright_runtime: @playwright_runtime)
    end

    private

    def enqueue_discovered_urls(source:, discovered_urls:)
      discovered_at = Time.current

      discovered_urls.each do |url|
        offer = upsert_offer_url(source: source, url: url, now: discovered_at)
        FetchJob.perform_later(url_hash: offer.url_hash)
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
