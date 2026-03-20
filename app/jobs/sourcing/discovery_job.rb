require "digest"

module Sourcing
  class DiscoveryJob < ApplicationJob
    def perform(source:, keyword:, work_mode:, page:)
      provider = Sourcing::Providers.registry.fetch(source)
      result = provider.discovery_step.call(
        source: source,
        keyword: keyword,
        work_mode: work_mode,
        page: page
      )

      discovered_at = Time.current

      result.fetch(:discovered_urls).each do |url|
        offer = upsert_offer_url(source: source, url: url, now: discovered_at)

        FetchJob.perform_later(url_hash: offer.url_hash)
      end

      if result.fetch(:has_next_page) && result[:next_job_data]
        self.class.perform_later(**result[:next_job_data])
      end
    end

    private

    def upsert_offer_url(source:, url:, now:)
      url_hash = Digest::SHA256.hexdigest(url)
      offer = JobOffer.find_or_initialize_by(url_hash: url_hash)

      offer.source = source
      offer.url = url
      offer.first_seen_at ||= now
      offer.last_seen_at = now
      offer.save!

      offer
    end
  end
end
