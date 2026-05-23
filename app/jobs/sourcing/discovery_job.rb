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
      @runtime = @discovery_step.setup(input: input)
      @seen_url_hashes = Set.new

      step :crawl do |job_step|
        page = Integer(job_step.cursor || input.fetch(:page, 1))

        loop do
          result = @discovery_step.crawl_page(
            input: input,
            runtime: @runtime,
            page: page
          )
          enqueue_discovered_urls(source: source, discovered_urls: result.fetch(:discovered_urls), keyword: keyword, force: force)

          break unless result.fetch(:has_next_page, false)

          page += 1
          job_step.advance! from: page
        end
      end

      @discovery_step.teardown(runtime: @runtime)
    end

    private

    def enqueue_discovered_urls(source:, discovered_urls:, keyword:, force: false)
      discovered_at = Time.current

      discovered_urls.each do |url|
        url_hash = Digest::SHA256.hexdigest(url)
        next unless @seen_url_hashes.add?(url_hash)

        offer = upsert_offer_url(source: source, url: url, url_hash: url_hash, now: discovered_at, keyword:)
        Sourcing::Pipeline.advance(offer, force: force)
      end
    end

    def upsert_offer_url(source:, url:, url_hash:, now:, keyword:)
      discovery_payload = { "at" => now.iso8601, "version" => @discovery_step.class::VERSION }

      JobOffer.upsert(
        {
          source: source,
          url: url,
          url_hash: url_hash,
          last_seen_at: now,
          steps_details: { "discovery" => discovery_payload },
        },
        unique_by: :url_hash,
        on_duplicate: Arel.sql(
          "last_seen_at = GREATEST(job_offers.last_seen_at, EXCLUDED.last_seen_at)"
        )
      )

      offer = JobOffer.find_by!(url_hash: url_hash)

      changed = false
      if offer.steps_details["discovery"].nil?
        offer.steps_details = offer.steps_details.merge("discovery" => discovery_payload)
        changed = true
      end
      changed = true if merge_keyword!(offer, keyword)
      offer.save! if changed
      offer
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
