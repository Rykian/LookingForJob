module Sourcing
  class FetchJob < ApplicationJob
    include Sourcing::Concerns::VersionChecking

    def perform(url_hash:, force: false)
      offer = JobOffer.find_by(url_hash: url_hash)
      return unless offer

      provider = Sourcing::Providers.registry.fetch(offer.source)
      current_version = provider.fetch_step.class::VERSION

      if should_skip_step?(offer, "fetch", current_version, force:)
        AnalyzeJob.perform_later(url_hash: offer.url_hash, force:)
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

      AnalyzeJob.perform_later(url_hash: offer.url_hash, force:)
    end
  end
end
