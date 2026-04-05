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

        COOKIE_CONSENT_SELECTORS = [
          "button[aria-label*='Accepter'][data-testid*='cookie']",
        ].freeze

        def initialize(fetcher: nil)
          @fetcher = fetcher || method(:fetch_with_playwright)
        end

        def call(input)
          url = input.fetch(:url)
          @fetcher.call(url: url)
        end

        private

        def fetch_with_playwright(url:)
          with_playwright_page(url: url, locale: "fr-FR") do |page_obj|
            click_first_selector(page_obj: page_obj, selectors: COOKIE_CONSENT_SELECTORS)

            # Wait for main content selectors
            found = wait_for_any_selector(page_obj: page_obj, selectors: MAIN_CONTENT_SELECTORS, timeout_ms: 4000)
            raise "WTTJ job page did not load main content" unless found

            html = page_obj.content
            ensure_basic_html_content!(provider_name: "WTTJ", url: url, html: html)
            html
          end
        end
      end
    end
  end
end
