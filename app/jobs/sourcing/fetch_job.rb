module Sourcing
  class FetchJob < ApplicationJob
    include Sourcing::Concerns::OfferJobArguments
    include Sourcing::Concerns::VersionChecking

    def perform(offer_id, options = {})
      force = extract_force(options)
      offer = find_offer(offer_id)
      return unless offer

      provider = Sourcing::Providers.registry.fetch(offer.source)
      current_version = provider.fetch_step.class::VERSION

      if should_skip_step?(offer, "fetch", current_version, force:)
        Sourcing::PipelineEvents.notify(Sourcing::PipelineEvents::OFFER_FETCHED, offer_id: offer.id, force:)
        return
      end

      html_content = provider.fetch_step.call(
        source: offer.source,
        url: offer.url,
        url_hash: offer.url_hash
      )

      if html_content.blank?
        raise Sourcing::Providers::Linkedin::FetchContentError,
              "LinkedIn fetch returned blank html_content for url_hash=#{offer.url_hash} url=#{offer.url}"
      end

      now = Time.current
      offer.html_file.attach(
        io: StringIO.new(html_content),
        filename: "#{offer.url_hash}.html",
        content_type: "text/html"
      )
      offer.update!(
        steps_details: offer.steps_details.merge("fetch" => {
          "at" => now.iso8601,
          "version" => current_version,
        })
      )

      Sourcing::PipelineEvents.notify(Sourcing::PipelineEvents::OFFER_FETCHED, offer_id: offer.id, force:)
    end
  end
end
