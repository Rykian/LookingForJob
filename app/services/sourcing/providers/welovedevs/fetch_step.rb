# frozen_string_literal: true

require "json"
require "uri"

module Sourcing
  module Providers
    module Welovedevs
      # Fetches a single WeLoveDevs offer as JSON from the public Algolia index.
      #
      # Discovery encodes the Algolia objectID in the URL as `?jobId=<objectID>`, which
      # maps directly to one get-object call — the hit carries the entire offer, so no
      # detail-page render is needed (and no Playwright). The raw JSON body is stored as
      # the offer payload (AnalyzeStep parses it structurally). A missing object (404)
      # raises OfferGoneError (→ FetchJob disables it).
      #
      # Legacy `/app/job/<seoAlias>` URLs from the previous (Playwright) implementation no
      # longer resolve on the site; they carry no jobId and are retired as gone offers.
      class FetchStep < Sourcing::FetchStep
        VERSION = 2

        def initialize(client: nil, fetcher: nil)
          super(fetcher: fetcher)
          @client = client
        end

        protected

        def fetch_page(url:)
          object_id = extract_object_id(url)
          unless object_id
            raise Sourcing::OfferGoneError,
                  "WeLoveDevs: legacy URL without jobId (offer superseded) for url=#{url}"
          end

          body = client.get_object(object_id)
          raise Sourcing::OfferGoneError, "WeLoveDevs: offer not found (HTTP 404) for url=#{url}" if body.nil?

          ensure_offer_payload!(url: url, body: body)
          body
        end

        private

        def extract_object_id(url)
          query = URI.parse(url.to_s).query
          return nil if query.nil?

          value = URI.decode_www_form(query).to_h["jobId"]
          value.to_s.strip.presence
        rescue URI::InvalidURIError
          nil
        end

        # The Algolia object must carry at least an objectID and a title. Anything else
        # means the offer is gone or the index shape drifted — fail loudly with context.
        def ensure_offer_payload!(url:, body:)
          data = JSON.parse(body)
          return if data.is_a?(Hash) && data["objectID"].present? && data["title"].to_s.strip.present?

          raise "WeLoveDevs: Algolia response is not a job payload for url=#{url}"
        rescue JSON::ParserError => e
          raise "WeLoveDevs: Algolia response is not valid JSON for url=#{url}: #{e.message}"
        end

        def client
          @client ||= AlgoliaClient.new
        end
      end
    end
  end
end
