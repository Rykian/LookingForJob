# frozen_string_literal: true

module Sourcing
  module Providers
    module Welovedevs
      # Fetches a single WeLoveDevs job offer detail page with Playwright.
      #
      # Detail pages are server-rendered and always embed a JSON-LD JobPosting block,
      # which is the marker of a valid offer. A removed/invalid offer renders without it,
      # so its absence is treated as a gone offer (OfferGoneError → FetchJob disables it).
      class FetchStep < Sourcing::FetchStep
        VERSION = 1

        # The JSON-LD JobPosting is the authoritative "this is a real offer" marker;
        # h1 is a softer fallback used to distinguish "nothing loaded" from "loaded but
        # not an offer".
        MAIN_CONTENT_SELECTORS = [
          "script[type='application/ld+json']",
          "h1",
        ].freeze

        JOB_POSTING_MARKER = "JobPosting"

        COOKIE_CONSENT_SELECTORS = [
          "#axeptio_btn_acceptAll",
          "button[aria-label*='accept' i]",
          "button[aria-label*='accepter' i]",
        ].freeze

        protected

        def fetch_page(url:)
          with_playwright_page(url: url, locale: "fr-FR") do |page_obj|
            click_first_selector(page_obj: page_obj, selectors: COOKIE_CONSENT_SELECTORS)

            found = wait_for_any_selector(
              page_obj: page_obj,
              selectors: MAIN_CONTENT_SELECTORS,
              timeout_ms: 10_000
            )

            html = page_obj.content
            ensure_basic_html_content!(provider_name: "WeLoveDevs", url: url, html: html)

            return html if html.include?(JOB_POSTING_MARKER)

            unless found
              raise Sourcing::OfferGoneError,
                    "WeLoveDevs: offer page has no JobPosting content (removed or unavailable) for url=#{url}"
            end

            raise "WeLoveDevs: page loaded without a JobPosting JSON-LD block (possible selector drift or non-offer page) for url=#{url}"
          end
        end
      end
    end
  end
end
