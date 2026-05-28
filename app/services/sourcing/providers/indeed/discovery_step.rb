# frozen_string_literal: true

require "uri"

module Sourcing
  module Providers
    module Indeed
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 1

        HOST = ENV.fetch("INDEED_HOST", "fr.indeed.com")
        BASE_URL = "https://#{HOST}/jobs".freeze
        PAGE_SIZE = 10
        MAX_PAGES = 10

        # Indeed renders each job result with data-jk on the result wrapper and
        # on the title anchor. data-jk is the canonical Indeed job id.
        JOB_CARD_SELECTORS = [
          "a[data-jk]",
          "[data-testid='slider_item'] a[data-jk]",
          "div.job_seen_beacon a[data-jk]",
        ].freeze

        # OneTrust banner on indeed.com.
        COOKIE_CONSENT_SELECTORS = [
          "#onetrust-accept-btn-handler",
          "button[aria-label*='Accept' i]",
          "button[aria-label*='Accepter' i]",
        ].freeze

        BLOCKED_PAGE_PATTERN = /(cloudflare|captcha|hcaptcha|recaptcha|verify you are (?:a )?human|access denied|just a moment)/i
        NO_RESULTS_PATTERN = /aucune offre|0\s+(?:emplois?|offres?)\s+correspond|did not match any jobs/i

        # Stable Indeed attribute filters for work mode. These attribute ids have
        # been used by Indeed for years to surface "Remote" and "Hybrid" facets.
        REMOTE_ATTR = "DSQF7"
        HYBRID_ATTR = "PAXZC"

        def initialize(crawler: nil)
          @crawler = crawler
        end

        def setup(input:)
          return { mode: :crawler } if @crawler

          require "playwright"

          session = Sourcing::Providers::Indeed::SessionManager.load_if_exists
          execution = Playwright.create(playwright_cli_executable_path: playwright_cli_executable_path)
          browser = execution.playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
          context = browser.new_context(**default_context_options(locale: "fr-FR", storage_state: session))

          {
            mode: :playwright,
            execution: execution,
            browser: browser,
            context: context,
            closed: false,
            session_loaded: !session.nil?,
          }
        rescue StandardError => e
          raise "Indeed discovery initialization failed: #{e.message}"
        end

        def crawl_page(input:, runtime:, page:)
          return @crawler.call(input: input, runtime: runtime, page: page) if @crawler

          context = runtime[:context]
          page_obj = context.new_page
          url = build_search_url(keyword: input[:keyword], work_mode: input[:work_mode], page: page)

          Rails.logger.info("Indeed Discovery: navigating to #{url}")
          page_obj.goto(url, waitUntil: "domcontentloaded", timeout: 45_000)
          page_obj.wait_for_timeout(1_000)

          if blocked_page?(page_obj)
            raise "Indeed discovery hit anti-bot challenge page for #{url}; provide a trusted session via bin/rails indeed:login"
          end

          click_first_selector(page_obj: page_obj, selectors: COOKIE_CONSENT_SELECTORS)

          found_selector = wait_for_any_selector(
            page_obj: page_obj,
            selectors: JOB_CARD_SELECTORS,
            timeout_ms: 8_000,
            wait_options: { state: "attached" }
          )

          if found_selector.nil?
            return { discovered_urls: [], has_next_page: false } if no_results_page?(page_obj)

            raise "Indeed discovery found no job cards on #{url}" if page <= 1

            return { discovered_urls: [], has_next_page: false }
          end

          jks = page_obj.eval_on_selector_all(
            "a[data-jk]",
            "els => [...new Set(els.map((e) => e.getAttribute('data-jk')).filter(Boolean))]"
          )

          links = jks.map { |jk| canonical_viewjob_url(jk) }.uniq

          Rails.logger.info("Indeed Discovery: page=#{page} found=#{links.size}")

          {
            discovered_urls: links,
            has_next_page: links.size >= PAGE_SIZE && page < MAX_PAGES,
          }
        rescue StandardError => e
          raise "Indeed crawl_page failed on page #{page}: #{e.message}"
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

        def canonical_viewjob_url(jk)
          "https://#{HOST}/viewjob?jk=#{jk}"
        end

        def blocked_page?(page_obj)
          title = page_obj.title.to_s
          body  = page_obj.evaluate("() => (document.body && document.body.innerText) || ''").to_s
          "#{title} #{body}".match?(BLOCKED_PAGE_PATTERN)
        rescue StandardError
          false
        end

        def no_results_page?(page_obj)
          text = page_obj.evaluate("() => (document.body && document.body.innerText) || ''").to_s
          text.match?(NO_RESULTS_PATTERN)
        rescue StandardError
          false
        end

        def build_search_url(keyword:, work_mode:, page:)
          start_offset = ([page.to_i, 1].max - 1) * PAGE_SIZE
          params = []
          params << ["q", keyword.to_s.strip] if keyword.present?
          params << ["start", start_offset.to_s] if start_offset.positive?
          if (sc_value = sc_for(work_mode))
            params << ["sc", sc_value]
          end

          "#{BASE_URL}?#{URI.encode_www_form(params)}"
        end

        def sc_for(work_mode)
          case work_mode.to_s
          when "", "nil"
            nil
          when "remote"
            "0kf:attr(#{REMOTE_ATTR});"
          when "hybrid"
            "0kf:attr(#{HYBRID_ATTR});"
          when "on-site"
            raise ArgumentError, "Indeed discovery does not expose a stable on-site-only filter"
          else
            raise ArgumentError, "Unsupported work_mode for Indeed discovery: #{work_mode.inspect}"
          end
        end
      end
    end
  end
end
