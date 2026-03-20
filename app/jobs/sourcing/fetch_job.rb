module Sourcing
  class FetchJob < ApplicationJob
    queue_as :sourcing_fetch

    def perform(url_hash:)
      offer = JobOffer.find_by(url_hash: url_hash)
      return unless offer

      html_content = FetchStep.new.call(
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
