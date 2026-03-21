module Sourcing
  class EnrichJob < ApplicationJob
    ENRICHED_ATTRIBUTES = %i[
      hybrid_remote_days_min_per_week
      primary_technologies
      secondary_technologies
      offer_language
      normalized_seniority
      english_level_required
    ].freeze

    def perform(url_hash:)
      offer = JobOffer.find_by(url_hash: url_hash)
      return unless offer&.html_content

      provider = Sourcing::Providers.registry.fetch(offer.source)
      enrichment = provider.enrich_step.call(
        source: offer.source,
        url: offer.url,
        url_hash: offer.url_hash,
        html_content: offer.html_content,
        extracted: offer.attributes.symbolize_keys.slice(
          :title,
          :company,
          :remote,
          :employment_type,
          :description_html,
          :salary_min_minor,
          :salary_max_minor,
          :salary_currency,
          :posted_at
        )
      )

      offer.update!(
        enrichment.slice(*ENRICHED_ATTRIBUTES).merge(enriched_at: Time.current)
      )
      Sourcing::ScoringJob.perform_later(url_hash: offer.url_hash)
    end
  end
end
