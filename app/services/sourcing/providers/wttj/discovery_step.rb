# frozen_string_literal: true

require "faraday"
require "nokogiri"
require "stringio"
require "time"
require "zlib"

module Sourcing
  module Providers
    module Wttj
      # Discovers WTTJ job URLs by combining two sources:
      #   1. Public XML sitemaps (always) — HTTP-only, no WAF, includes lastmod.
      #   2. /fr/jobs-matches (only if a saved session exists) — personalized
      #      matches via Playwright with stored cookies.
      #
      # Search-page crawling was removed because WTTJ added AWS WAF on CloudFront
      # which rejects every headless browser request to frontend page routes.
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 2

        SITEMAP_BASE = "https://www.welcometothejungle.com/sitemaps/job-listings"
        MAX_SITEMAP_INDEX = 10
        DEFAULT_RECENCY_DAYS = 14

        JOBS_MATCHES_URL = "https://www.welcometothejungle.com/fr/jobs-matches"
        JOB_LINK_SELECTOR = "a[href^='/fr/companies/'][href*='/jobs/']"
        COOKIE_CONSENT_SELECTOR = "button[aria-label*='Accepter'][data-testid*='cookie']"
        NEXT_PAGE_BUTTON_SELECTOR = "button[data-testid='pagination-next']"
        JOBS_MATCHES_MAX_PAGES = 5

        def initialize(connection: nil)
          @injected_connection = connection
        end

        def supports_work_mode_filter?
          false
        end

        # Discovery fits the base contract: setup gathers the full URL list
        # up-front (sitemap + optional jobs-matches), crawl_page returns them
        # all on page 1, teardown is a no-op. DiscoveryJob calls these directly.
        def setup(input:)
          sitemap_urls = discover_from_sitemaps(input)
          matches_urls = Sourcing::Providers::Wttj::SessionManager.exists? ? discover_from_jobs_matches(input) : []
          { urls: (sitemap_urls + matches_urls).uniq }
        end

        def crawl_page(input:, runtime:, page:)
          return { discovered_urls: [], has_next_page: false } if page > 1

          { discovered_urls: runtime.fetch(:urls, []), has_next_page: false }
        end

        def teardown(runtime:)
          nil
        end

        private

        def discover_from_sitemaps(input)
          connection = sitemap_connection
          cutoff = recency_cutoff(input)
          keyword_slug = input[:keyword].to_s.downcase.tr(" ", "-").presence
          urls = []

          (0..MAX_SITEMAP_INDEX).each do |index|
            sitemap_url = "#{SITEMAP_BASE}.#{index}.xml.gz"
            response = connection.get(sitemap_url)

            unless response.success?
              Rails.logger.warn("WTTJ Discovery: sitemap #{index} returned HTTP #{response.status}")
              next
            end

            xml = decode_sitemap_body(response.body.to_s)
            doc = Nokogiri::XML(xml)
            doc.remove_namespaces!

            doc.css("url").each do |node|
              loc = node.at_css("loc")&.text
              lastmod = node.at_css("lastmod")&.text
              next unless loc&.include?("/fr/companies/")
              next if lastmod && Time.parse(lastmod) < cutoff
              next if keyword_slug && !loc.downcase.include?(keyword_slug)

              urls << loc
            end
          end

          Rails.logger.info("WTTJ Discovery: sitemap found=#{urls.size}")
          urls
        rescue StandardError => e
          Rails.logger.warn("WTTJ Discovery: sitemap traversal failed (#{e.class}: #{e.message})")
          []
        end

        def discover_from_jobs_matches(_input)
          require "playwright"

          session = Sourcing::Providers::Wttj::SessionManager.load
          urls = []
          page_number = 1

          Playwright.create(playwright_cli_executable_path: playwright_cli_executable_path) do |runtime|
            browser = runtime.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
            context = browser.new_context(**default_context_options(locale: "fr-FR", storage_state: session))

            begin
              loop do
                page_obj = context.new_page
                url = page_number == 1 ? JOBS_MATCHES_URL : "#{JOBS_MATCHES_URL}?page=#{page_number}"
                Rails.logger.info("WTTJ Discovery: jobs-matches navigating to #{url}")
                page_obj.goto(url, waitUntil: "domcontentloaded")

                click_first_selector(page_obj: page_obj, selectors: [COOKIE_CONSENT_SELECTOR])

                found = wait_for_any_selector(page_obj: page_obj, selectors: [JOB_LINK_SELECTOR], timeout_ms: 5_000)
                break unless found

                links = page_obj.eval_on_selector_all(JOB_LINK_SELECTOR, "elements => elements.map(e => e.href)")
                urls.concat(Array(links))

                has_next = page_number < JOBS_MATCHES_MAX_PAGES && page_obj.query_selector(NEXT_PAGE_BUTTON_SELECTOR)
                page_obj.close
                break unless has_next

                page_number += 1
              end
            ensure
              context.close
              browser.close
            end
          end

          Rails.logger.info("WTTJ Discovery: jobs-matches found=#{urls.size}")
          urls.uniq
        rescue StandardError => e
          Rails.logger.warn("WTTJ Discovery: jobs-matches failed (#{e.class}: #{e.message}); falling back to sitemap-only")
          []
        end

        # Some HTTP adapters (including Faraday's default Net::HTTP) auto-decompress
        # gzip responses, others return the raw gzip bytes. Handle both transparently.
        def decode_sitemap_body(body)
          return body if body.start_with?("<?xml") || body.start_with?("<urlset")

          Zlib::GzipReader.new(StringIO.new(body)).read
        end

        def sitemap_connection
          # Sitemaps are bot-facing. AWS WAF challenges browser-like User-Agents
          # but lets crawler-style UAs through. Identify as a crawler explicitly.
          @injected_connection || Faraday.new do |f|
            f.headers["User-Agent"] = "LookingForJob-Sourcing/1.0 (+sitemap-crawler)"
            f.options.timeout = 30
            f.options.open_timeout = 10
            f.adapter Faraday.default_adapter
          end
        end

        def recency_cutoff(input)
          days = Integer(input[:days] || DEFAULT_RECENCY_DAYS)
          Time.now - days * 86_400
        end
      end
    end
  end
end
