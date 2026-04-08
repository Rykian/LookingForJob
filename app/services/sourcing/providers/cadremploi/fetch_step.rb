# frozen_string_literal: true

module Sourcing
  module Providers
    module Cadremploi
      class FetchStep < Sourcing::FetchStep
        VERSION = 1

        COOKIE_CONSENT_SELECTORS = [
          "#didomi-notice-agree-button",
          "button[aria-label*='Tout accepter' i]",
          "button[aria-label*='Accepter' i]",
        ].freeze

        # The job title should be visible for any valid offer page.
        MAIN_CONTENT_SELECTORS = [
          "h1",
          "[class*='job-title']",
          "[class*='offer-title']",
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
          session = Sourcing::Providers::Cadremploi::SessionManager.load_if_required!

          with_playwright_page(url: url, locale: "fr-FR", storage_state: session) do |page_obj|
            click_first_selector(page_obj: page_obj, selectors: COOKIE_CONSENT_SELECTORS)

            found = wait_for_any_selector(
              page_obj: page_obj,
              selectors: MAIN_CONTENT_SELECTORS,
              timeout_ms: 5000
            )
            raise "Cadremploi: job page did not load a title element (possible auth wall or Cloudflare block)" unless found

            html = page_obj.content
            ensure_basic_html_content!(provider_name: "Cadremploi", url: url, html: html)
            html
          end
        end
      end
    end
  end
end
