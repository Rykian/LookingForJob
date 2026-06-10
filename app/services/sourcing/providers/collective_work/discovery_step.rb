# frozen_string_literal: true

require "faraday"
require "json"
require "uri"

module Sourcing
  module Providers
    module CollectiveWork
      # Discovers Collective.work job URLs from the public listing
      # (https://www.collective.work/jobs/fr).
      #
      # The listing is a Next.js page that server-renders the search payload into a
      # `<script id="__NEXT_DATA__">` block. The hydrated React-Query state at
      # `props.pageProps.dehydratedState.queries[0].state.data.results` carries the
      # current page's `projects[]` (30 per page) and total count, so discovery is plain
      # HTTP: no Playwright, no auth, no anti-bot.
      #
      # Keyword filtering uses the `?search=<keyword>` query param (the form on the page
      # rewrites the URL with this param; passing it server-side filters the SSR payload).
      # Pagination uses `?page=<N>` (1-indexed). Work-mode filters could not be encoded in
      # the URL — they are passed to a client-side mutation only — so per-offer work mode
      # is captured in analyze instead.
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 1

        BASE_URL = "https://www.collective.work"
        LISTING_PATH = "/jobs/fr"
        OFFER_URL_TEMPLATE = "#{BASE_URL}/jobs/fr/%s".freeze
        NEXT_DATA_REGEXP = %r{<script id="__NEXT_DATA__"[^>]*>(.*?)</script>}m
        PAGE_SIZE = 30
        MAX_PAGES = 200 # safety cap: ~6000 offers at 30/page

        def initialize(crawler: nil, connection: nil)
          @crawler = crawler
          @injected_connection = connection
        end

        # The `workPreferences` filter is only applied via a client-side React Query
        # mutation; the SSR payload ignores it, so we cannot filter at the URL level.
        def supports_work_mode_filter?
          false
        end

        def setup(input:)
          { mode: @crawler ? :crawler : :http }
        end

        def crawl_page(input:, runtime:, page:)
          return @crawler.call(input: input, runtime: runtime, page: page) if @crawler
          return { discovered_urls: [], has_next_page: false } if page > MAX_PAGES

          url = build_search_url(keyword: input[:keyword], page: page)
          Rails.logger.info("CollectiveWork Discovery: GET #{url}")

          html = fetch_html(url)
          results = extract_results(html)
          projects = Array(results["projects"])
          total = results.dig("pagination", "total").to_i
          from = results.dig("pagination", "from").to_i

          discovered_urls = projects.filter_map { |p| offer_url(p["slug"]) }
          has_next_page = projects.any? && (from + projects.size) < total

          Rails.logger.info(
            "CollectiveWork Discovery: page=#{page} found=#{discovered_urls.size} from=#{from} total=#{total} next=#{has_next_page}"
          )

          { discovered_urls: discovered_urls, has_next_page: has_next_page }
        rescue StandardError => e
          raise "CollectiveWork crawl_page failed (page=#{page}): #{e.message}"
        end

        def teardown(runtime:)
          nil
        end

        private

        def build_search_url(keyword:, page:)
          params = {}
          params[:search] = keyword if keyword.to_s.strip.length.positive?
          params[:page] = page if page.to_i > 1

          url = "#{BASE_URL}#{LISTING_PATH}"
          url += "?#{URI.encode_www_form(params)}" unless params.empty?
          url
        end

        def offer_url(slug)
          return nil unless slug.is_a?(String) && !slug.empty?

          format(OFFER_URL_TEMPLATE, slug)
        end

        def fetch_html(url)
          response = connection.get(url)
          raise "HTTP #{response.status} for #{url}" unless response.success?

          response.body
        end

        # Pulls the React-Query SearchJobs results out of the embedded __NEXT_DATA__ blob.
        def extract_results(html)
          match = html.match(NEXT_DATA_REGEXP)
          raise "no __NEXT_DATA__ script tag found" unless match

          data = JSON.parse(match[1])
          queries = data.dig("props", "pageProps", "dehydratedState", "queries") || []
          search_query = queries.find { |q| Array(q["queryKey"]).first.to_s == "PublicPages_SearchJobs" }
          raise "no PublicPages_SearchJobs query in __NEXT_DATA__" unless search_query

          search_query.dig("state", "data", "results") || {}
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
