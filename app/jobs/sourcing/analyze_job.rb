module Sourcing
  class AnalyzeJob < ApplicationJob
    queue_as :sourcing_analyze

    ANALYZED_ATTRIBUTES = %i[
      title
      company
      remote
      employment_type
      description_html
      salary_min_minor
      salary_max_minor
      salary_currency
      posted_at
    ].freeze

    def perform(url_hash:)
      offer = JobOffer.find_by(url_hash: url_hash)
      return unless offer&.html_content

      provider = Sourcing::Providers.registry.fetch(offer.source)
      extracted = provider.analyze_step.call(
        source: offer.source,
        url: offer.url,
        url_hash: offer.url_hash,
        html_content: offer.html_content
      )

      offer.update!(extracted.slice(*ANALYZED_ATTRIBUTES))

      EnrichJob.perform_later(url_hash: offer.url_hash)
    end
  end
end
