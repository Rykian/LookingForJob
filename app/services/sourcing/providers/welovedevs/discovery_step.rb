# frozen_string_literal: true

require "json"
require "set"
require "uri"

module Sourcing
  module Providers
    module Welovedevs
      # Discovers WeLoveDevs job URLs from the public job search.
      #
      # The listing is an Algolia InstantSearch app (index "public_jobs") rendered
      # client-side. It renders no per-offer detail links — clicking a card only updates a
      # `?jobId=` query param via client routing — so there is nothing to scrape from the
      # DOM. Instead, Playwright renders `https://www.welovedevs.com/app/jobs?query=<keyword>`
      # and we capture the Algolia search responses it fires, reading each hit's `seoAlias`
      # (the canonical detail slug) to build `/app/job/<slug>` URLs. Scrolling triggers the
      # next Algolia page (infinite scroll), so we scroll until no new hits arrive.
      #
      # No authentication, anti-bot, or consent wall blocks the search, so no session
      # is required.
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 1

        SEARCH_URL = "https://www.welovedevs.com/app/jobs"
        OFFER_URL_TEMPLATE = "https://www.welovedevs.com/app/job/%s"
        ALGOLIA_URL_PATTERN = /algolia/i
        MAX_SCROLLS = 40
        SCROLL_WAIT_MS = 1_500
        INITIAL_WAIT_MS = 5_000
        # Stop after this many consecutive scrolls produce no new hits.
        STALE_SCROLL_LIMIT = 2

        # Best-effort cookie/consent dismissal — the banner overlays content but does
        # not gate the search, so this is optional.
        COOKIE_CONSENT_SELECTORS = [
          "#axeptio_btn_acceptAll",
          "button[aria-label*='accept' i]",
          "button[aria-label*='accepter' i]",
        ].freeze

        def initialize(crawler: nil)
          @crawler = crawler
        end

        # WeLoveDevs search filters by free-text keyword (Algolia relevance). A reliable
        # work-mode (remote/hybrid/on-site) refinement could not be encoded in the URL,
        # so discovery runs once per keyword and location is captured per-offer in analyze.
        def supports_work_mode_filter?
          false
        end

        def setup(input:)
          return { mode: :crawler } if @crawler

          require "playwright"

          execution = Playwright.create(playwright_cli_executable_path: playwright_cli_executable_path)
          browser = execution.playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
          context = browser.new_context(**default_context_options(locale: "fr-FR"))

          { mode: :playwright, execution:, browser:, context:, closed: false }
        rescue StandardError => e
          raise "WeLoveDevs discovery initialization failed: #{e.message}"
        end

        # All hits are collected on page 1 via scroll-driven Algolia pagination, so the
        # base pagination loop stops here (WTTJ-style).
        def crawl_page(input:, runtime:, page:)
          return @crawler.call(input: input, runtime: runtime, page: page) if @crawler
          return { discovered_urls: [], has_next_page: false } if page > 1

          page_obj = runtime[:context].new_page
          slugs = Set.new
          page_obj.on("response", ->(response) { collect_slugs(response, slugs) })

          url = build_search_url(input[:keyword])
          Rails.logger.info("WeLoveDevs Discovery: navigating to #{url}")
          page_obj.goto(url, waitUntil: "domcontentloaded", timeout: 45_000)

          click_first_selector(page_obj: page_obj, selectors: COOKIE_CONSENT_SELECTORS)
          page_obj.wait_for_timeout(INITIAL_WAIT_MS)
          scroll_until_stable(page_obj, slugs)

          discovered_urls = slugs.map { |slug| offer_url(slug) }
          Rails.logger.info("WeLoveDevs Discovery: keyword=#{input[:keyword].inspect} found=#{discovered_urls.size}")

          { discovered_urls: discovered_urls, has_next_page: false }
        rescue StandardError => e
          raise "WeLoveDevs crawl_page failed: #{e.message}"
        ensure
          page_obj&.close
        end

        def teardown(runtime:)
          return if runtime[:mode] == :crawler
          return if runtime[:closed]

          runtime[:browser]&.close
          runtime[:execution]&.stop
          runtime[:closed] = true
        end

        private

        def build_search_url(keyword)
          normalized = keyword.to_s.strip
          return SEARCH_URL if normalized.empty?

          "#{SEARCH_URL}?#{URI.encode_www_form('query' => normalized)}"
        end

        def offer_url(slug)
          format(OFFER_URL_TEMPLATE, slug)
        end

        # Scrolls to the bottom to trigger the next Algolia page until hits stop growing.
        def scroll_until_stable(page_obj, slugs)
          stale = 0

          MAX_SCROLLS.times do
            before = slugs.size
            page_obj.evaluate("() => window.scrollTo(0, document.body.scrollHeight)")
            page_obj.wait_for_timeout(SCROLL_WAIT_MS)

            if slugs.size > before
              stale = 0
            else
              stale += 1
              break if stale >= STALE_SCROLL_LIMIT
            end
          end
        end

        # Response listener: extracts hit slugs from Algolia search responses.
        def collect_slugs(response, slugs)
          return unless response.url =~ ALGOLIA_URL_PATTERN

          data = JSON.parse(response.body)
          Array(data["results"]).each do |result|
            next unless result.is_a?(Hash)

            Array(result["hits"]).each do |hit|
              slug = hit["seoAlias"]
              slugs << slug if slug.is_a?(String) && !slug.empty?
            end
          end
        rescue StandardError
          # Non-JSON bodies, redirects, or transient body-read errors are not fatal to
          # discovery — skip them.
          nil
        end
      end
    end
  end
end
