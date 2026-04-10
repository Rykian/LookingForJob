module Sourcing
  class AnalyzeJob < ApplicationJob
    include Sourcing::Concerns::OfferJobArguments
    include Sourcing::Concerns::VersionChecking

    ANALYZED_ATTRIBUTES = %i[
      title
      company
      location_mode
      employment_type
      description_html
      salary_min_minor
      salary_max_minor
      salary_currency
      posted_at
      city
    ].freeze

    def perform(offer_id, options = {})
      force = extract_force(options)
      offer = find_offer(offer_id)
      return unless offer&.html_file&.attached?

      provider = Sourcing::Providers.registry.fetch(offer.source)
      current_version = provider.analyze_step.class::VERSION

      if should_skip_step?(offer, "analyze", current_version, force:)
        Sourcing::PipelineEvents.notify(Sourcing::PipelineEvents::OFFER_ANALYZED, offer_id: offer.id, force:)
        return
      end

      extracted = provider.analyze_step.call(
        source: offer.source,
        url: offer.url,
        url_hash: offer.url_hash,
        html_content: offer.html_file.download
      )

      offer.update!(extracted.slice(*ANALYZED_ATTRIBUTES).merge(
        steps_details: offer.steps_details.merge("analyze" => {
          "at" => Time.current.iso8601,
          "version" => current_version,
        })
      ))

      Sourcing::PipelineEvents.notify(Sourcing::PipelineEvents::OFFER_ANALYZED, offer_id: offer.id, force:)
    end
  end
end
