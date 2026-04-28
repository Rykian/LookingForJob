require "digest"

module Sourcing
  class DiscoveryJob < BaseJob
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
          enqueue_discovered_urls(source: source, discovered_urls: result.fetch(:discovered_urls), keyword: keyword, force: force)

          break unless result.fetch(:has_next_page, false)

          page += 1
          job_step.advance! from: page
        end
      end

      @discovery_step.close_playwright(playwright_runtime: @playwright_runtime)
    end

    private

    def enqueue_discovered_urls(source:, discovered_urls:, keyword:, force: false)
      discovered_at = Time.current

      discovered_urls.each do |url|
        offer = upsert_offer_url(source: source, url: url, now: discovered_at, keyword:)
        Sourcing::PipelineEvents.notify(Sourcing::PipelineEvents::OFFER_DISCOVERED, offer_id: offer.id, force:)
      end
    end

    def upsert_offer_url(source:, url:, now:, keyword:)
      url_hash = Digest::SHA256.hexdigest(url)
      offer = JobOffer.find_or_initialize_by(url_hash: url_hash)

      offer.source = source
      offer.url = url
      merge_keyword!(offer, keyword)
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
      updated = false
      if existing_offer.last_seen_at.nil? || existing_offer.last_seen_at < now
        existing_offer.last_seen_at = now
        updated = true
      end
      updated ||= merge_keyword!(existing_offer, keyword)
      existing_offer.save! if updated
      existing_offer
    rescue ActiveRecord::RecordInvalid => e
      unless uniqueness_validation_error?(e.record)
        raise
      end

      existing_offer = JobOffer.find_by(url_hash: url_hash) || JobOffer.find_by(url: url)
      raise unless existing_offer

      updated = false
      if existing_offer.last_seen_at.nil? || existing_offer.last_seen_at < now
        existing_offer.last_seen_at = now
        updated = true
      end
      updated ||= merge_keyword!(existing_offer, keyword)
      existing_offer.save! if updated
      existing_offer
    end

    def uniqueness_validation_error?(record)
      record.errors.added?(:url, :taken) || record.errors.added?(:url_hash, :taken)
    end

    def merge_keyword!(offer, keyword)
      normalized_keyword = normalize_keyword(keyword)
      return false if normalized_keyword.blank?

      offer.keywords = Array(offer.keywords)
      return false if offer.keywords.include?(normalized_keyword)

      offer.keywords << normalized_keyword
      true
    end

    def normalize_keyword(keyword)
      keyword.to_s.gsub(/[^a-zA-Z\s]/, " ").downcase.gsub(/\s+/, " ").strip
    end
  end
end
