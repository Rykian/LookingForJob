module Sourcing
  module Providers
    module FranceTravail
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 1

        SEARCH_BASE_URL    = "https://candidat.francetravail.fr/offres/recherche"
        OFFER_BASE_URL     = "https://candidat.francetravail.fr"
        JOB_LINK_SELECTOR  = "ul.result-list li.result a.media[href*='/offres/recherche/detail/']"
        NEXT_PAGE_SELECTOR = "#zoneAfficherPlus a.btn"
        RESULTS_SELECTOR   = "ul.result-list"
        MAX_CLICKS         = 100  # 100 loads × 20 offers = up to 2000 per keyword

        def initialize(crawler: nil)
          @crawler = crawler
        end

        # --------------- DiscoveryStep contract ---------------

        def setup(input:)
          return { mode: :crawler } if @crawler

          require "playwright"
          execution = Playwright.create(playwright_cli_executable_path: playwright_cli_executable_path)
          browser = execution.playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
          context = browser.new_context

          {
            mode: :playwright,
            execution:,
            browser:,
            context:,
            closed: false,
          }
        rescue StandardError => e
          raise "FranceTravail discovery initialization failed: #{e.message}"
        end

        def crawl_every_pages(input:, runtime:)
          discovered_urls = crawl_all_urls(input: input, runtime: runtime)
          { discovered_urls: discovered_urls.uniq }
        end

        # DiscoveryJob expects crawl_page with has_next_page. FranceTravail uses
        # load-more on a single URL, so we return all discovered URLs in one pass.
        def crawl_page(input:, runtime:, page:)
          discovered_urls = crawl_all_urls(input: input, runtime: runtime)

          {
            discovered_urls: discovered_urls.uniq,
            has_next_page: false,
          }
        end

        def crawl_all_urls(input:, runtime:)
          if @crawler
            result = @crawler.call(input: input, runtime: runtime)
            return Array(result[:discovered_urls])
          end

          context = runtime[:context]
          page_obj = context.new_page
          discovered_urls = []
          clicks = 0

          url = build_search_url(input[:keyword])
          Rails.logger.info("FranceTravail Discovery: navigating to #{url}")
          page_obj.goto(url, waitUntil: "domcontentloaded")
          handle_cookie_consent(page_obj)

          # Wait for results list; if it doesn't appear within timeout, assume no results found
          # (e.g., searching for "Elixir" when no jobs match the criteria)
          begin
            page_obj.wait_for_selector(RESULTS_SELECTOR, timeout: 5_000)
          rescue StandardError => e
            Rails.logger.info("FranceTravail Discovery: no results found for keyword=#{input[:keyword]}")
            return []
          end

          loop do
            batch = page_obj.eval_on_selector_all(
              JOB_LINK_SELECTOR,
              "els => els.map(e => e.getAttribute('href'))"
            ).map { |href| "#{OFFER_BASE_URL}#{href}" }

            new_count = batch.size - discovered_urls.size
            discovered_urls = batch  # eval_on_selector_all always returns full list
            Rails.logger.info("FranceTravail Discovery: total=#{discovered_urls.size} new_this_load=#{new_count}")

            next_btn = page_obj.query_selector(NEXT_PAGE_SELECTOR)
            break unless next_btn && clicks < MAX_CLICKS

            # Click "Afficher les 20 offres suivantes" and wait for new items
            previous_count = discovered_urls.size
            next_btn.click
            page_obj.wait_for_timeout(1500)
            current_count = page_obj.eval_on_selector_all(JOB_LINK_SELECTOR, "els => els.length")
            break if current_count <= previous_count

            clicks += 1
          end

          discovered_urls
        rescue => e
          raise "FranceTravail crawl_every_pages failed: #{e.message}"
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
          require "cgi"
          "#{SEARCH_BASE_URL}?motsCles=#{CGI.escape(keyword.to_s)}&offresPartenaires=true&rayon=10&tri=0"
        end

        def handle_cookie_consent(page_obj)
          # France Travail may show a GDPR cookie banner on first visit.
          # Selectors are best-effort; failures are silently ignored.
          click_first_selector(
            page_obj: page_obj,
            selectors: %w[
              #pecookieConsent button
              button[id*="accept"]
              button[id*="cookie"]
            ]
          )
        rescue
          # Cookie consent is non-blocking
        end
      end
    end
  end
end
