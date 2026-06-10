# frozen_string_literal: true

require "faraday"
require "json"

module Sourcing
  module Providers
    module CollectiveWork
      # Fetches a Collective.work offer detail page over plain HTTP.
      #
      # Detail pages are server-rendered (Next.js); the full offer payload lives in the
      # `<script id="__NEXT_DATA__">` block at `props.pageProps.project`. A removed/invalid
      # offer renders the same shell but with `project=null` (or a 404), so an absent
      # project hash is treated as a gone offer (OfferGoneError → FetchJob disables it).
      class FetchStep < Sourcing::FetchStep
        VERSION = 1

        NEXT_DATA_REGEXP = %r{<script id="__NEXT_DATA__"[^>]*>(.*?)</script>}m

        def initialize(connection: nil, fetcher: nil)
          super(fetcher: fetcher)
          @injected_connection = connection
        end

        protected

        def fetch_page(url:)
          response = connection.get(url)

          raise Sourcing::OfferGoneError, "CollectiveWork: offer not found (HTTP 404) for url=#{url}" if response.status == 404
          raise "CollectiveWork fetch HTTP #{response.status} for url=#{url}" unless response.success?

          html = response.body
          ensure_basic_html_content!(provider_name: "CollectiveWork", url: url, html: html)
          ensure_offer_payload_present!(url: url, html: html)
          html
        end

        private

        # The detail page must carry a non-null `project` hash in __NEXT_DATA__. Anything
        # else (missing tag, null project, missing key) means the offer is gone or the
        # provider changed its data shape — fail loudly with context.
        def ensure_offer_payload_present!(url:, html:)
          match = html.match(NEXT_DATA_REGEXP)
          unless match
            raise "CollectiveWork: page loaded without __NEXT_DATA__ (possible selector drift) for url=#{url}"
          end

          data = JSON.parse(match[1])
          project = data.dig("props", "pageProps", "project")
          return if project.is_a?(Hash) && !project.empty?

          raise Sourcing::OfferGoneError,
                "CollectiveWork: offer page has no project payload (removed or unavailable) for url=#{url}"
        rescue JSON::ParserError => e
          raise "CollectiveWork: __NEXT_DATA__ is not valid JSON for url=#{url}: #{e.message}"
        end

        def connection
          @injected_connection || Faraday.new do |f|
            f.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
            f.headers["Accept"] = "text/html,application/xhtml+xml"
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
