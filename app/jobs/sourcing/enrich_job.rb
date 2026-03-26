module Sourcing
  class EnrichJob < ApplicationJob
    include Sourcing::Concerns::VersionChecking

    ENRICHED_ATTRIBUTES = %i[
      hybrid_remote_days_min_per_week
      primary_technologies
      secondary_technologies
      offer_language
      normalized_seniority
      english_level_required
    ].freeze

    def perform(url_hash:, force: false)
      offer = JobOffer.find_by(url_hash: url_hash)
      return unless offer&.html_file&.attached?

      provider = Sourcing::Providers.registry.fetch(offer.source)
      current_version = provider.enrich_step.class::VERSION

      if should_skip_step?(offer, "enrich", current_version, force:)
        Sourcing::ScoringJob.perform_later(url_hash: offer.url_hash, force:)
        return
      end

      enrichment = provider.enrich_step.call(
        source: offer.source,
        url: offer.url,
        url_hash: offer.url_hash,
        html_content: offer.html_file.download,
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

      now = Time.current
      offer.update!(
        enrichment.slice(*ENRICHED_ATTRIBUTES).merge(
          steps_details: offer.steps_details.merge("enrich" => {
            "at" => now.iso8601,
            "version" => current_version,
          })
        )
      )
      Sourcing::ScoringJob.perform_later(url_hash: offer.url_hash, force:)
    end
  end
end
