# frozen_string_literal: true

require "uri"

module Sourcing
  module Providers
    module Welovedevs
      # Discovers WeLoveDevs job URLs from the public Algolia `public_jobs` index.
      #
      # WeLoveDevs is a client-side Algolia InstantSearch app with no scrapeable detail
      # links — it routes to offers via a `?jobId=<objectID>` query param. We query the
      # same open Algolia search endpoint the site uses directly over HTTP (no Playwright),
      # paginating through every result page, and build canonical
      # `https://www.welovedevs.com/app/jobs?jobId=<objectID>` URLs that FetchStep resolves
      # back to a single get-object call. Keyword filtering is Algolia relevance on `query`.
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 2

        OFFER_URL_TEMPLATE = "https://www.welovedevs.com/app/jobs?jobId=%s"
        HITS_PER_PAGE = 100
        MAX_PAGES = 50 # safety cap: 5000 offers at 100/page
        # Only real company postings carry detail pages; spontaneous-application entries
        # are company landing cards with no offer to fetch.
        OFFER_TYPE = "company_job"

        def initialize(client: nil)
          @client = client
        end

        # WeLoveDevs search filters by free-text keyword (Algolia relevance). A reliable
        # work-mode (remote/hybrid/on-site) refinement could not be encoded as a stable
        # Algolia facet filter, so discovery runs once per keyword and location_mode is
        # captured per-offer in analyze.
        def supports_work_mode_filter?
          false
        end

        def setup(input:)
          { client: @client || AlgoliaClient.new }
        end

        def crawl_page(input:, runtime:, page:)
          # Algolia pages are 0-indexed; the pipeline loop is 1-indexed.
          algolia_page = page - 1
          return { discovered_urls: [], has_next_page: false } if algolia_page >= MAX_PAGES

          result = runtime[:client].search(
            query: input[:keyword].to_s.strip,
            page: algolia_page,
            hits_per_page: HITS_PER_PAGE
          )

          discovered_urls = Array(result["hits"]).filter_map { |hit| offer_url(hit) }
          nb_pages = result["nbPages"].to_i
          has_next_page = algolia_page + 1 < nb_pages

          Rails.logger.info(
            "WeLoveDevs Discovery: keyword=#{input[:keyword].inspect} page=#{page} found=#{discovered_urls.size} total=#{result["nbHits"]} next=#{has_next_page}"
          )

          { discovered_urls: discovered_urls, has_next_page: has_next_page }
        rescue StandardError => e
          raise "WeLoveDevs crawl_page failed (page=#{page}): #{e.message}"
        end

        def teardown(runtime:)
          nil
        end

        private

        def offer_url(hit)
          return nil unless hit.is_a?(Hash)
          return nil unless hit["type"].to_s == OFFER_TYPE

          object_id = hit["objectID"]
          return nil unless object_id.is_a?(String) && !object_id.empty?

          format(OFFER_URL_TEMPLATE, URI.encode_www_form_component(object_id))
        end
      end
    end
  end
end
