module Sourcing
  class FetchJob < ApplicationJob
    def perform(url_hash:)
      offer = JobOffer.find_by(url_hash: url_hash)
      return unless offer

      provider = Sourcing::Providers.registry.fetch(offer.source)
      html_content = provider.fetch_step.call(
        source: offer.source,
        url: offer.url,
        url_hash: offer.url_hash
      )

      offer.update!(
        html_content: html_content,
        fetched_at: Time.current
      )

      AnalyzeJob.perform_later(url_hash: offer.url_hash)
    end
  end
end
