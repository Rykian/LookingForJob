# frozen_string_literal: true

require "uri"

module Sourcing
  module Providers
    module Apec
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 1

        BASE_URL = "https://www.apec.fr/candidat/recherche-emploi.html/emploi"
        JOB_LINK_SELECTOR = "a[href*='/candidat/recherche-emploi.html/emploi/detail-offre/']"
        COMPANY_TYPE_IDS = %w[143684 143685 143686 143687 143706].freeze
        HYBRID_TELEWORK_IDS = %w[20765 20766].freeze
        REMOTE_TELEWORK_IDS = %w[20767].freeze
        PAGE_SIZE = 20
        MAX_PAGES = 25

        BLOCKED_PAGE_PATTERN = /(cloudflare|captcha|challenge|access denied|forbidden|verify you are human|robot)/i
        NO_RESULTS_PATTERN = /(0\s+offres correspondent|aucune offre ne correspond)/i

        def initialize(crawler: nil)
          @crawler = crawler
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
          raise "Apec discovery initialization failed: #{e.message}"
        end

        def crawl_page(input:, playwright_runtime:, page:)
          return @crawler.call(input: input, playwright_runtime: playwright_runtime, page: page) if @crawler

          context = playwright_runtime[:context]
          page_obj = context.new_page
          url = build_search_url(keyword: input[:keyword], work_mode: input[:work_mode], page: page)

          page_obj.goto(url, waitUntil: "domcontentloaded", timeout: 45_000)
          raise "Apec discovery hit anti-bot challenge page for #{url}" if blocked_page?(page_obj)

          found_selector = wait_for_any_selector(
            page_obj: page_obj,
            selectors: [JOB_LINK_SELECTOR],
            timeout_ms: 8_000,
            wait_options: { state: "attached" }
          )

          if found_selector.nil?
            return { discovered_urls: [], has_next_page: false } if no_results_page?(page_obj)

            unless page > 1
              raise "Apec discovery found no job links on #{url}"
            end

            return { discovered_urls: [], has_next_page: false }
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
            has_next_page: links.size >= PAGE_SIZE && page < MAX_PAGES,
          }
        rescue StandardError => e
          raise "Apec crawl_page failed on page #{page}: #{e.message}"
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

        def no_results_page?(page_obj)
          text = page_obj.evaluate("() => (document.body && document.body.innerText) || ''").to_s
          text.match?(NO_RESULTS_PATTERN)
        rescue StandardError
          false
        end

        def build_search_url(keyword:, work_mode:, page:)
          page_index = [page.to_i - 1, 0].max
          params = []

          COMPANY_TYPE_IDS.each { |value| params << ["typesConvention", value] }
          params << ["motsCles", keyword.to_s.strip] if keyword.present?
          params << ["page", page_index.to_s]
          telework_ids_for(work_mode).each { |value| params << ["typesTeletravail", value] }

          "#{BASE_URL}?#{URI.encode_www_form(params)}"
        end

        def telework_ids_for(work_mode)
          case work_mode.to_s
          when "", nil.to_s
            []
          when "remote"
            REMOTE_TELEWORK_IDS
          when "hybrid"
            HYBRID_TELEWORK_IDS
          when "on-site"
            raise ArgumentError, "Apec discovery does not expose a stable on-site-only filter"
          else
            raise ArgumentError, "Unsupported work_mode for Apec discovery: #{work_mode.inspect}"
          end
        end
      end
    end
  end
end
