module Sourcing
  class AnalyzeJob < BaseJob
    include Sourcing::Concerns::OfferJobArguments

    DEFAULT_ANALYZED_ATTRIBUTES = %i[
      title
      company_name
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
      return if offer.rejected? || offer.disabled?

      html_content = offer.html_file.download

      if offer.keywords.present? && !Sourcing::RelevanceChecker.new.call(offer.keywords, html_content)
        offer.update!(rejected: true)
        return
      end

      provider = Sourcing::Providers.registry.fetch(offer.source)
      current_version = provider.analyze_step.class::VERSION

      if Sourcing::Pipeline.should_skip?(offer, "analyze", force:)
        Sourcing::Pipeline.advance(offer, "analyze", run_id, force:)
        return
      end

      extracted = provider.analyze_step.call(
        source: offer.source,
        url: offer.url,
        url_hash: offer.url_hash,
        html_content: html_content
      )

      if extracted[:disabled]
        offer.update!(disabled: true)
        return
      end

      attrs = extracted.slice(*analyzed_attributes(provider))
      if attrs.key?(:company_name)
        attrs[:normalized_company_name] = Company.normalize(attrs[:company_name]).presence
      end

      offer.update!(attrs.merge(
        steps_details: offer.steps_details.merge("analyze" => {
          "at" => Time.current.iso8601,
          "version" => current_version,
        })
      ))

      identify_duplicate(offer)
      Sourcing::DeduplicateOffersJob.perform_later

      return if offer.duplicate?

      Sourcing::Pipeline.advance(offer, "analyze", run_id, force:)
    end

    private

    def identify_duplicate(offer)
      fp = Sourcing::DeduplicateOffersService.compute_content_fingerprint(offer.company_name, offer.title, offer.city)
      return unless fp

      offer.update_column(:content_fingerprint, fp)

      canonical = JobOffer
        .where(content_fingerprint: fp)
        .where.not(id: offer.id)
        .where("COALESCE(posted_at, created_at) >= ?", 14.days.ago)
        .where(rejected: false, disabled: false)
        .order(:created_at)
        .first
      return unless canonical

      offer.update_column(:canonical_id, canonical.canonical_id || canonical.id)
    end

    def analyzed_attributes(provider)
      step_class = provider.analyze_step.class
      return DEFAULT_ANALYZED_ATTRIBUTES unless step_class.const_defined?(:PERSISTED_ATTRIBUTES, false)

      step_class.const_get(:PERSISTED_ATTRIBUTES)
    end
  end
end
