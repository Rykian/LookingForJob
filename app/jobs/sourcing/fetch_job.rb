module Sourcing
  class FetchJob < ApplicationJob
    def perform(url_hash:)
      offer = JobOffer.find_by(url_hash: url_hash)
      return unless offer

      provider = Sourcing::Providers.registry.fetch(offer.source)
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
        steps_details: offer.steps_details.merge("fetch" => { "at" => now.iso8601, "version" => 1 })
      )

      AnalyzeJob.perform_later(url_hash: offer.url_hash)
    end
  end
end
