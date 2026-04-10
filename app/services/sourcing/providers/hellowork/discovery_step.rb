# frozen_string_literal: true

require "uri"

module Sourcing
  module Providers
    module Hellowork
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 1

        BASE_URL = "https://www.hellowork.com/fr-fr/emploi/recherche.html"
        JOB_LINK_SELECTOR = "a[href*='/fr-fr/emplois/'][href$='.html']"
        MIN_EXPECTED_FULL_PAGE_RESULTS = 30
        MAX_PAGES = 10

        BLOCKED_PAGE_PATTERN = /(cloudflare|captcha|challenge|access denied|forbidden|verify you are human|robot)/i

        def initialize(crawler: nil)
          @crawler = crawler
        end

        def supports_work_mode_filter?
          false
        end

        def initialize_playwright(input:)
          return { mode: :crawler } if @crawler

          require "playwright"

          execution = Playwright.create(playwright_cli_executable_path: playwright_cli_executable_path)
          browser = execution.playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
          context = browser.new_context(**default_context_options(locale: "fr-FR"))

          {
            mode: :playwright,
            execution: execution,
            browser: browser,
            context: context,
            closed: false,
          }
        rescue StandardError => e
          raise "Hellowork discovery initialization failed: #{e.message}"
        end

        def crawl_page(input:, playwright_runtime:, page:)
          return @crawler.call(input: input, playwright_runtime: playwright_runtime, page: page) if @crawler

          context = playwright_runtime[:context]
          page_obj = context.new_page

          url = build_search_url(keyword: input[:keyword], page: page)
          Rails.logger.info("Hellowork discovery: navigating to #{url}")
          page_obj.goto(url, waitUntil: "domcontentloaded", timeout: 45_000)

          raise "Hellowork discovery hit anti-bot challenge page for #{url}" if blocked_page?(page_obj)

          found_selector = wait_for_any_selector(
            page_obj: page_obj,
            selectors: [JOB_LINK_SELECTOR],
            timeout_ms: 8_000,
            wait_options: { state: "attached" }
          )
          unless found_selector
            raise "Hellowork discovery found no job links on #{url}" if page <= 1

            return {
              discovered_urls: [],
              has_next_page: false,
            }
          end

          links = page_obj.eval_on_selector_all(
            JOB_LINK_SELECTOR,
            <<~JS
              els => [...new Set(els.map((e) => {
                const href = e.getAttribute('href') || e.href;
                return new URL(href, window.location.origin).toString();
              }))]
            JS
          ).map { |raw_url| clean_url(raw_url) }.uniq

          {
            discovered_urls: links,
            has_next_page: links.size >= MIN_EXPECTED_FULL_PAGE_RESULTS && page < MAX_PAGES,
          }
        rescue StandardError => e
          raise "Hellowork crawl_page failed on page #{page}: #{e.message}"
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
          uri.query = nil
          uri.fragment = nil
          uri.to_s
        rescue URI::InvalidURIError
          url
        end

        def blocked_page?(page_obj)
          title = page_obj.title.to_s
          text = page_obj.evaluate("() => (document.body && document.body.innerText) || ''").to_s
          "#{title} #{text}".match?(BLOCKED_PAGE_PATTERN)
        rescue StandardError
          false
        end

        def build_search_url(keyword:, page:)
          params = {}
          params[:k] = keyword.to_s.strip if keyword.present?
          params[:p] = page.to_i if page.to_i > 1

          query = URI.encode_www_form(params)
          query.empty? ? BASE_URL : "#{BASE_URL}?#{query}"
        end
      end
    end
  end
end
