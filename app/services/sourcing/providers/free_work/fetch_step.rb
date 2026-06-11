# frozen_string_literal: true

require "faraday"
require "json"

module Sourcing
  module Providers
    module FreeWork
      # Fetches a Free-Work offer as JSON from the public API.
      #
      # The slug is the last segment of the public detail URL
      # (/fr/tech-it/<category>/job-mission/<slug>) and maps directly to
      # `GET /api/job_postings/<slug>`. The raw JSON body is stored as the offer
      # payload (AnalyzeStep parses it structurally). A removed offer returns 404
      # (OfferGoneError → FetchJob disables it).
      class FetchStep < Sourcing::FetchStep
        VERSION = 1

        BASE_URL = "https://www.free-work.com"
        API_PATH = "/api/job_postings"
        SLUG_REGEXP = %r{/job-mission/([^/?#]+)}

        def initialize(connection: nil, fetcher: nil)
          super(fetcher: fetcher)
          @injected_connection = connection
        end

        protected

        def fetch_page(url:)
          slug = extract_slug!(url)
          response = connection.get("#{BASE_URL}#{API_PATH}/#{slug}")

          raise Sourcing::OfferGoneError, "FreeWork: offer not found (HTTP 404) for url=#{url}" if response.status == 404
          raise "FreeWork fetch HTTP #{response.status} for url=#{url}" unless response.success?

          body = response.body
          ensure_offer_payload!(url: url, body: body)
          body
        end

        private

        def extract_slug!(url)
          match = url.to_s.match(SLUG_REGEXP)
          raise "FreeWork: cannot extract slug from url=#{url} (expected /job-mission/<slug>)" unless match

          match[1]
        end

        # The API must return a job posting object with at least an id and a title.
        # Anything else means the offer is gone or the provider changed its data
        # shape — fail loudly with context.
        def ensure_offer_payload!(url:, body:)
          data = JSON.parse(body)
          return if data.is_a?(Hash) && data["id"].present? && data["title"].to_s.strip.present?

          raise "FreeWork: API response is not a job posting payload for url=#{url}"
        rescue JSON::ParserError => e
          raise "FreeWork: API response is not valid JSON for url=#{url}: #{e.message}"
        end

        def connection
          @injected_connection || Faraday.new do |f|
            f.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
            f.headers["Accept"] = "application/json"
            f.headers["Accept-Language"] = "fr-FR,fr;q=0.9,en;q=0.8"
            f.options.timeout = 30
            f.options.open_timeout = 10
            f.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end
