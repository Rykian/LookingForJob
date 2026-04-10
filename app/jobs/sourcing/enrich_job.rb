module Sourcing
  class EnrichJob < ApplicationJob
    include Sourcing::Concerns::OfferJobArguments
    include Sourcing::Concerns::VersionChecking

    ENRICHED_ATTRIBUTES = %i[
      hybrid_remote_days_min_per_week
      primary_technologies
      secondary_technologies
      offer_language
      normalized_seniority
      english_level_required
    ].freeze

    def perform(offer_id, options = {})
      force = extract_force(options)
      offer = find_offer(offer_id)
      return unless offer&.html_file&.attached?

      provider = Sourcing::Providers.registry.fetch(offer.source)
      current_version = provider.enrich_step.class::VERSION

      if should_skip_step?(offer, "enrich", current_version, force:)
        Sourcing::PipelineEvents.notify(Sourcing::PipelineEvents::OFFER_ENRICHED, offer_id: offer.id, force:)
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
          :location_mode,
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
      Sourcing::PipelineEvents.notify(Sourcing::PipelineEvents::OFFER_ENRICHED, offer_id: offer.id, force:)
    end
  end
end
