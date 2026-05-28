# frozen_string_literal: true

module Sourcing
  module Providers
    module Wttj
      class FetchStep < Sourcing::FetchStep
        VERSION = 2

        MAIN_CONTENT_SELECTORS = [
          "h1",
          "script[type='application/ld+json']",
          "h2",
          "section",
          "[data-testid]",
          "[class*='job']",
          "[class*='description']",
        ].freeze

        COOKIE_CONSENT_SELECTORS = [
          "button[aria-label*='Accepter'][data-testid*='cookie']",
        ].freeze

        CHALLENGE_PAGE_PATTERN = /(challenge|aws-waf-token|just a moment|access denied|verify you are (?:a )?human)/i
        RATE_LIMIT_PAGE_PATTERN = /(too many requests|rate.?limit|429)/i

        REQUEST_DELAY_RANGE = (2.0..4.0).freeze

        protected

        def fetch_page(url:)
          session = Sourcing::Providers::Wttj::SessionManager.load_if_exists
          throttle!

          with_playwright_page(url: url, locale: "fr-FR", storage_state: session) do |page_obj|
            click_first_selector(page_obj: page_obj, selectors: COOKIE_CONSENT_SELECTORS)

            page_text = page_text(page_obj)

            if page_text.match?(RATE_LIMIT_PAGE_PATTERN)
              raise "WTTJ: rate-limited for #{url}; slow down or rotate egress"
            end

            if page_text.match?(CHALLENGE_PAGE_PATTERN)
              raise "WTTJ: anti-bot challenge page for #{url}; provide a trusted session via bin/rails wttj:login"
            end

            found = wait_for_any_selector(page_obj: page_obj, selectors: MAIN_CONTENT_SELECTORS, timeout_ms: 8_000)
            raise "WTTJ: job page did not load main content for #{url}" unless found

            html = page_obj.content
            ensure_basic_html_content!(provider_name: "WTTJ", url: url, html: html)
            html
          end
        end

        private

        def page_text(page_obj)
          title = page_obj.title.to_s
          body  = page_obj.evaluate("() => (document.body && document.body.innerText) || ''").to_s
          "#{title} #{body}"
        rescue StandardError
          ""
        end

        # Jittered pause between successive WTTJ fetches in the same worker
        # process. Sidekiq concurrency=1 (in Sourcing::FetchJob) already prevents
        # parallel fetches; this adds the per-request gap on top.
        def throttle!
          target = rand(REQUEST_DELAY_RANGE)
          if @last_request_at
            elapsed = Time.now - @last_request_at
            remaining = target - elapsed
            sleep(remaining) if remaining.positive?
          end
          @last_request_at = Time.now
        end
      end
    end
  end
end
