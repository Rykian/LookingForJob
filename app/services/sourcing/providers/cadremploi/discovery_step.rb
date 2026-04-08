# frozen_string_literal: true

require "uri"

module Sourcing
  module Providers
    module Cadremploi
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 1

        BASE_URL = "https://www.cadremploi.fr/emploi/liste_offres"
        JOB_LINK_SELECTOR = "a[href*='/emploi/detail_offre?offreId=']"
        MAX_PAGES = 10

        # Cadremploi uses Didomi for GDPR consent.
        COOKIE_CONSENT_SELECTORS = [
          "#didomi-notice-agree-button",
          "button[aria-label*='Tout accepter' i]",
          "button[aria-label*='Accepter' i]",
        ].freeze

        def initialize(crawler: nil)
          @crawler = crawler
        end

        def initialize_playwright(input:)
          return { mode: :crawler } if @crawler

          require "playwright"

          session = Sourcing::Providers::Cadremploi::SessionManager.load_if_required!
          execution = Playwright.create(playwright_cli_executable_path: playwright_cli_executable_path)
          browser = execution.playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
          context = browser.new_context(**default_context_options(locale: "fr-FR", storage_state: session))

          {
            mode: :playwright,
            execution:,
            browser:,
            context:,
            closed: false,
            session_loaded: !session.nil?,
          }
        rescue StandardError => e
          raise "Cadremploi discovery initialization failed: #{e.message}"
        end

        def crawl_page(input:, playwright_runtime:, page:)
          return @crawler.call(input: input, playwright_runtime: playwright_runtime, page: page) if @crawler

          context = playwright_runtime[:context]
          page_obj = context.new_page

          url = build_search_url(input[:keyword], page)
          Rails.logger.info("Cadremploi Discovery: navigating to #{url}")
          page_obj.goto(url, waitUntil: "domcontentloaded", timeout: 45_000)

          # Cadremploi can keep background network activity open for a long time,
          # so avoid waiting for full network idle before extraction.
          page_obj.wait_for_timeout(1000)

          if challenge_page?(page_obj)
            raise "Cadremploi returned an anti-bot challenge page; provide a trusted session in #{Sourcing::Providers::Cadremploi::SessionManager.path}"
          end

          click_first_selector(page_obj: page_obj, selectors: COOKIE_CONSENT_SELECTORS)

          wait_for_any_selector(page_obj: page_obj, selectors: [JOB_LINK_SELECTOR], timeout_ms: 8000)

          job_links = page_obj.eval_on_selector_all(
            JOB_LINK_SELECTOR,
            "els => [...new Set(els.map(e => e.href))]"
          ).map { |url| clean_url(url) }.uniq

          Rails.logger.info("Cadremploi Discovery: page=#{page} found=#{job_links.size}")

          {
            discovered_urls: job_links,
            has_next_page: !job_links.empty? && page < MAX_PAGES,
          }
        rescue => e
          raise "Cadremploi crawl_page failed on page #{page}: #{e.message}"
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

        private

        def clean_url(url)
          uri = URI.parse(url)
          uri.fragment = nil
          uri.to_s
        rescue URI::InvalidURIError
          url
        end

        def challenge_page?(page_obj)
          title = page_obj.title.to_s
          body = page_obj.content.to_s

          title.match?(/just a moment/i) ||
            body.match?(/checking your browser/i) ||
            body.match?(/cf[- ]?challenge|cloudflare/i)
        rescue StandardError
          false
        end

        def build_search_url(keyword, page)
          require "uri"
          params = []
          if keyword.present?
            normalized = keyword.to_s.strip
            capitalized = normalized.sub(/\A\p{Lower}/) { |m| m.upcase }

            params << "motsCles=#{URI.encode_www_form_component(normalized)}"
            params << "motscles=#{URI.encode_www_form_component(capitalized)}"
          end
          params << "page=#{page}" if page.to_i > 1
          [BASE_URL, params.join("&")].reject(&:empty?).join("?")
        end
      end
    end
  end
end
