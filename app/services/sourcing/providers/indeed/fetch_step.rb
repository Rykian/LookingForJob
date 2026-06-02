# frozen_string_literal: true

module Sourcing
  module Providers
    module Indeed
      class FetchStep < Sourcing::FetchStep
        VERSION = 1

        COOKIE_CONSENT_SELECTORS = [
          "#onetrust-accept-btn-handler",
          "button[aria-label*='Accept' i]",
          "button[aria-label*='Accepter' i]",
        ].freeze

        # Stable markers on /viewjob pages. JSON-LD is present on virtually every
        # offer; the h1 inside #viewJobSSRRoot or jobsearch-JobInfoHeader is the
        # legacy fallback. #jobDescriptionText has been the description anchor
        # for years.
        MAIN_CONTENT_SELECTORS = [
          "script[type='application/ld+json']",
          "h1[data-testid='jobsearch-JobInfoHeader-title']",
          "h1.jobsearch-JobInfoHeader-title",
          "#jobDescriptionText",
        ].freeze

        BLOCKED_PAGE_PATTERN = /(cloudflare|captcha|hcaptcha|recaptcha|verify you are (?:a )?human|access denied|just a moment)/i

        protected

        def fetch_page(url:)
          session = Sourcing::Providers::Indeed::SessionManager.load_if_exists

          with_playwright_page(url: url, locale: "fr-FR", storage_state: session) do |page_obj|
            click_first_selector(page_obj: page_obj, selectors: COOKIE_CONSENT_SELECTORS)

            if blocked_page?(page_obj)
              raise "Indeed: anti-bot challenge page for #{url}; provide a trusted session via bin/rails indeed:login"
            end

            found = wait_for_any_selector(
              page_obj: page_obj,
              selectors: MAIN_CONTENT_SELECTORS,
              timeout_ms: 8_000
            )

            unless found
              raise Sourcing::OfferGoneError, "Indeed: offer gone at #{url}" if gone_offer_page?(page_obj, url)
              raise "Indeed: job page did not load main content for #{url} (possible auth wall, expired offer, or selector drift)"
            end

            html = page_obj.content
            ensure_basic_html_content!(provider_name: "Indeed", url: url, html: html)
            html
          end
        end

        private

        def gone_offer_page?(page_obj, url)
          http_status = page_obj.evaluate(
            "() => (performance.getEntriesByType('navigation')[0]?.responseStatus ?? 0)"
          ).to_i
          http_status == 404
        end

        def blocked_page?(page_obj)
          title = page_obj.title.to_s
          body  = page_obj.evaluate("() => (document.body && document.body.innerText) || ''").to_s
          "#{title} #{body}".match?(BLOCKED_PAGE_PATTERN)
        rescue StandardError
          false
        end
      end
    end
  end
end
