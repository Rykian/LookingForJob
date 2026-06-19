# frozen_string_literal: true

require "faraday"
require "json"
require "uri"

module Sourcing
  module Providers
    module Welovedevs
      # Thin client over WeLoveDevs' public Algolia index (`public_jobs`).
      #
      # The site is a client-side Algolia InstantSearch app; the same search and
      # get-object endpoints it consumes are open (the application id and search-only
      # API key are embedded verbatim in the site JS), so both discovery and fetch run
      # as plain HTTP with no Playwright, no auth, and no anti-bot challenge. A WeLoveDevs
      # hit carries the entire offer (title, company, salary, contracts, remotePolicy,
      # markdown description), so a single get-object call replaces the old detail-page
      # crawl.
      class AlgoliaClient
        APP_ID  = "G9S2J15G1N"
        # Search-only key, published in the site bundle — not a secret.
        API_KEY = "c041e0948eb090ebd0612b9920b2e27d"
        INDEX   = "public_jobs"
        BASE_URL = "https://#{APP_ID.downcase}-dsn.algolia.net".freeze

        def initialize(connection: nil)
          @connection = connection
        end

        # One search page. Returns the parsed Algolia result hash for `public_jobs`
        # (`hits`, `nbPages`, `page`, ...).
        def search(query:, page:, hits_per_page:)
          params = URI.encode_www_form(
            "query" => query.to_s,
            "hitsPerPage" => hits_per_page,
            "page" => page
          )
          body = { requests: [{ indexName: INDEX, params: params }] }

          response = connection.post("/1/indexes/*/queries", JSON.generate(body))
          raise "WeLoveDevs Algolia search HTTP #{response.status}" unless response.success?

          result = JSON.parse(response.body).dig("results", 0)
          raise "WeLoveDevs Algolia search: missing results for query=#{query.inspect} page=#{page}" unless result.is_a?(Hash)

          result
        end

        # Fetches a single offer by its Algolia objectID. Returns the raw JSON body
        # string (stored verbatim by FetchStep). Returns nil when the offer is gone (404).
        def get_object(object_id)
          response = connection.get("/1/indexes/#{INDEX}/#{URI.encode_www_form_component(object_id)}")
          return nil if response.status == 404
          raise "WeLoveDevs Algolia get_object HTTP #{response.status} for objectID=#{object_id}" unless response.success?

          response.body
        end

        private

        def connection
          @connection ||= Faraday.new(url: BASE_URL) do |f|
            f.headers["X-Algolia-API-Key"] = API_KEY
            f.headers["X-Algolia-Application-Id"] = APP_ID
            f.headers["Content-Type"] = "application/json"
            f.options.timeout = 30
            f.options.open_timeout = 10
            f.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end
