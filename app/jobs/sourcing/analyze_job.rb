module Sourcing
  class AnalyzeJob < ApplicationJob
    include Sourcing::Concerns::OfferJobArguments
    include Sourcing::Concerns::VersionChecking

    DEFAULT_ANALYZED_ATTRIBUTES = %i[
      title
      company
      location_mode
      city
      employment_type
      description_html
      salary_min_minor
      salary_max_minor
      salary_currency
      posted_at
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

      offer.update!(extracted.slice(*analyzed_attributes(provider)).merge(
        steps_details: offer.steps_details.merge("analyze" => {
          "at" => Time.current.iso8601,
          "version" => current_version,
        })
      ))

      Sourcing::PipelineEvents.notify(Sourcing::PipelineEvents::OFFER_ANALYZED, offer_id: offer.id, force:)
    end

    private

    def analyzed_attributes(provider)
      step_class = provider.analyze_step.class
      return DEFAULT_ANALYZED_ATTRIBUTES unless step_class.const_defined?(:PERSISTED_ATTRIBUTES, false)

      step_class.const_get(:PERSISTED_ATTRIBUTES)
    end
  end
end
