module Sourcing
  module Providers
    module Wttj
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 1

        JOB_LINK_SELECTOR = "a[href^='/fr/companies/'][href*='/jobs/']"
        COOKIE_CONSENT_SELECTOR = "button[aria-label*='Accepter'][data-testid*='cookie']"
        NEXT_PAGE_BUTTON_SELECTOR = "button[data-testid='pagination-next']"
        MAX_PAGES = 10

        def initialize(crawler: nil)
          @crawler = crawler
        end

        def initialize_playwright(input:)
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
          raise "WTTJ discovery initialization failed: #{e.message}"
        end

        def crawl_page(input:, playwright_runtime:, page:)
          return @crawler.call(input: input, playwright_runtime: playwright_runtime, page: page) if @crawler

          context = playwright_runtime[:context]
          page_obj = context.new_page

          # Build the search URL with real WTTJ parameters
          require "cgi"
          base_url = "https://www.welcometothejungle.com/fr/jobs"
          params = []
          # Search text
          if input[:keyword]
            params << "query=#{CGI.escape(input[:keyword].to_s)}"
          end
          # Country filter (default to France)
          params << "refinementList%5Boffices.country_code%5D%5B%5D=FR"
          # Remote/hybrid/on-site filter
          if input[:work_mode]
            remote_param = case input[:work_mode]
            when "remote" then "fulltime"
            when "hybrid" then "partial"
            when "on-site", "onsite" then "no"
            when "punctual" then "punctual"
            else nil
            end
            params << "refinementList%5Bremote%5D%5B%5D=#{remote_param}" if remote_param
          end
          params << "page=#{page}"
          url = "#{base_url}?#{params.join("&")}"
          Rails.logger.info("WTTJ Discovery: Navigating to #{url}")
          page_obj.goto(url, waitUntil: "domcontentloaded")

          # Handle cookie consent popup if present
          if page_obj.query_selector(COOKIE_CONSENT_SELECTOR)
            page_obj.click(COOKIE_CONSENT_SELECTOR)
          end

          # Wait for job links to appear
          page_obj.wait_for_selector(JOB_LINK_SELECTOR, timeout: 5000)

          # Extract job URLs
          job_links = page_obj.eval_on_selector_all(JOB_LINK_SELECTOR, "elements => elements.map(e => e.href)")

          # Check for next page (simulate infinite scroll or look for next button)
          has_next_page = false
          if page < MAX_PAGES && page_obj.query_selector(NEXT_PAGE_BUTTON_SELECTOR)
            has_next_page = true
          end

          { discovered_urls: job_links, has_next_page: has_next_page }
        rescue => e
          raise "WTTJ crawl_page failed on page #{page}: #{e.message}"
        ensure
          page_obj&.close
        end

        def close_playwright(playwright_runtime:)
          return if playwright_runtime[:mode] == :crawler
          return if playwright_runtime[:closed]

          playwright_runtime[:browser]&.close
          playwright_runtime[:execution]&.stop
          playwright_runtime[:closed] = true
        end
      end
    end
  end
end
