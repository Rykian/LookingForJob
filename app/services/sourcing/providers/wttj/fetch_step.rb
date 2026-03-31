module Sourcing
  module Providers
    module Wttj
      class FetchStep < Sourcing::FetchStep
        VERSION = 1

        MAIN_CONTENT_SELECTORS = [
          "h1", # Job title (visible)
          "h2", # Section headings (e.g., Le poste, L'entreprise)
          "section", # Generic section fallback
          "[data-testid]", # Any element with a data-testid (WTTJ uses these)
          "[class*='job']", # Class contains 'job' (broad fallback)
          "[class*='description']", # Class contains 'description'
        ].freeze

        COOKIE_CONSENT_SELECTOR = "button[aria-label*='Accepter'][data-testid*='cookie']"

        def initialize(fetcher: nil)
          @fetcher = fetcher || method(:fetch_with_playwright)
        end

        def call(input)
          url = input.fetch(:url)
          @fetcher.call(url: url)
        end

        private

        def fetch_with_playwright(url:)
          require "playwright"

          html = nil

          Playwright.create(playwright_cli_executable_path: "npx playwright") do |playwright|
            browser = playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
            context = browser.new_context(
              viewport: { width: 1366, height: 768 },
              locale: "fr-FR",
              timezoneId: "Europe/Paris",
              userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
            )
            page_obj = context.new_page
            page_obj.goto(url, waitUntil: "domcontentloaded")

            # Handle cookie consent popup if present
            if page_obj.query_selector(COOKIE_CONSENT_SELECTOR)
              page_obj.click(COOKIE_CONSENT_SELECTOR)
            end

            # Wait for main content selectors
            found = false
            MAIN_CONTENT_SELECTORS.each do |selector|
              begin
                page_obj.wait_for_selector(selector, timeout: 4000)
                found = true
                break
              rescue
                # Try next selector
              end
            end
            raise "WTTJ job page did not load main content" unless found

            html = page_obj.content
            page_obj.close
            browser.close
          end
          html
        end
      end
    end
  end
end
