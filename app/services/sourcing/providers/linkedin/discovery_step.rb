require "uri"

module Sourcing
  module Providers
    module Linkedin
      class DiscoveryContentError < StandardError; end
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 1

        PAGE_SIZE = 25
        MAX_PAGES = 10
        JOB_CARD_SELECTOR = "li.scaffold-layout__list-item[data-occludable-job-id]"
        JOB_LINK_SELECTOR = "a[href*='/jobs/view/']"
        NEXT_PAGE_SELECTORS = [
          "button[aria-label*='Next']",
          "button[aria-label*='Suivant']",
          "button.jobs-search-pagination__button--next",
        ].freeze

        # +crawler+ is an optional callable used in tests. It receives the same
        # keyword args as the real per-page crawl and must return
        # { discovered_urls: [...], has_next_page: true/false }.
        def initialize(crawler: nil)
          @crawler = crawler
        end

        def initialize_playwright(input:)
          return { mode: :crawler } if @crawler

          require "playwright"

          session = Sourcing::Providers::Linkedin::SessionManager.load
          execution = Playwright.create(playwright_cli_executable_path: playwright_cli_executable_path)
          browser = execution.playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
          context = browser.new_context(storageState: session)

          {
            mode: :playwright,
            execution: execution,
            browser: browser,
            context: context,
            closed: false,
          }
        rescue Sourcing::Providers::Linkedin::SessionNotFoundError
          raise
        rescue StandardError => e
          source = input[:source]
          work_mode = input[:work_mode]
          raise "LinkedIn discovery initialization failed for source=#{source} work_mode=#{work_mode}: #{e.message}"
        end

        def crawl_every_pages(input:, playwright_runtime:)
          super
        end

        def crawl_page(input:, playwright_runtime:, page:)
          source = input.fetch(:source)
          keyword = input.fetch(:keyword)
          work_mode = input.fetch(:work_mode)

          raw = if playwright_runtime[:mode] == :crawler
            @crawler.call(source: source, keyword: keyword, work_mode: work_mode, page: page)
          else
            crawl_page_with_context(
              context: playwright_runtime.fetch(:context),
              source: source,
              keyword: keyword,
              work_mode: work_mode,
              page: page
            )
          end

          urls = Array(raw[:discovered_urls]).map { |u| clean_url(u) }.uniq
          has_next_page = raw.fetch(:has_next_page, urls.any? && page < MAX_PAGES) && page < MAX_PAGES

          {
            discovered_urls: urls,
            has_next_page: has_next_page,
          }
        end

        def close_playwright(playwright_runtime:)
          return if playwright_runtime.nil?
          return if playwright_runtime[:closed]
          return if playwright_runtime[:mode] == :crawler

          playwright_runtime[:context]&.close
          playwright_runtime[:browser]&.close
          playwright_runtime[:execution]&.stop
        ensure
          playwright_runtime[:closed] = true
        end

        def clean_url(url)
          uri = URI.parse(url)
          uri.query = nil
          uri.fragment = nil
          uri.to_s
        end

        private

        def crawl_page_with_context(context:, source:, keyword:, work_mode:, page:)
          url = build_search_url(keyword: keyword, work_mode: work_mode, page: page)
          result = { discovered_urls: [], has_next_page: false }

          page_obj = context.new_page

          begin
            page_obj.goto(url, waitUntil: "domcontentloaded")

            # Diagnostics for shell/login/challenge/interstitial
            title = page_obj.title.to_s
            current_url = page_obj.url.to_s
            body_text_length = page_obj.evaluate(<<~JS)
              () => {
                const body = document && document.body ? document.body.innerText : "";
                return (body || "").trim().length;
              }
            JS
            html = page_obj.content.to_s
            compact_html = html.downcase.gsub(/\s+/, "")
            blocked_pattern = /(checkpoint|challenge|captcha|authwall|login|sign in|security verification)/i
            if compact_html == "<html><head></head><body></body></html>" || compact_html == "<html><body></body></html>"
              raise DiscoveryContentError, "LinkedIn discovery produced shell_html for url=#{url}"
            end
            if "#{current_url} #{title}".downcase.match?(blocked_pattern)
              raise DiscoveryContentError, "LinkedIn discovery reached challenge_or_login_page for url=#{url} current_url=#{current_url} title=#{title.inspect}"
            end

            cards_found = begin
              page_obj.wait_for_selector(JOB_CARD_SELECTOR, timeout: 15_000, state: "attached")
              true
            rescue => e
              Rails.logger.warn("LinkedIn discovery: no job cards for source=#{source} page=#{page}: #{e.message}")
              false
            end

            if !cards_found
              raise DiscoveryContentError, "LinkedIn discovery found no job cards for url=#{url} title=#{title.inspect} body_text_length=#{body_text_length}"
            end

            hydrate_search_results(page_obj)

            hrefs = page_obj.evaluate(<<~JS, arg: { card: JOB_CARD_SELECTOR, link: JOB_LINK_SELECTOR })
              ({ card, link }) => {
                const base = window.location.origin;
                const seen = new Set();
                const urls = [];
                for (const item of document.querySelectorAll(card)) {
                  const anchor = item.querySelector(link);
                  if (anchor && anchor.href) {
                    if (!seen.has(anchor.href)) { seen.add(anchor.href); urls.push(anchor.href); }
                  } else {
                    const jobId = item.getAttribute("data-occludable-job-id");
                    if (jobId) {
                      const url = base + "/jobs/view/" + jobId + "/";
                      if (!seen.has(url)) { seen.add(url); urls.push(url); }
                    }
                  }
                }
                return urls;
              }
            JS

            result[:discovered_urls] = Array(hrefs).uniq
            result[:has_next_page] = next_page_available?(page_obj) && page < MAX_PAGES
          ensure
            page_obj.close rescue nil
          end

          result
        end

        def build_search_url(keyword:, work_mode:, page:)
          params = {
            keywords: keyword,
            start: (page - 1) * PAGE_SIZE,
          }

          # LinkedIn remote/hybrid filter (f_WT) is passed from WORK_MODE.
          params[:f_WT] = case work_mode
          when "remote" then "2"
          when "hybrid" then "3"
          when "onsite" then "1"
          else nil
          end

          "https://www.linkedin.com/jobs/search/?#{URI.encode_www_form(params)}"
        end

        def hydrate_search_results(page_obj)
          page_obj.wait_for_timeout(rand(1_000..2_000))

          page_obj.evaluate(<<~JS, arg: JOB_CARD_SELECTOR)
            async (selector) => {
              const items = Array.from(document.querySelectorAll(selector));
              for (const item of items) {
                item.scrollIntoView({ block: "center" });
                await new Promise((r) => window.setTimeout(r, 120));
              }
            }
          JS

          page_obj.wait_for_timeout(rand(300..700))
        end

        def next_page_available?(page_obj)
          selector = NEXT_PAGE_SELECTORS.join(", ")
          btn = page_obj.query_selector(selector)
          return false unless btn

          btn.get_attribute("disabled").nil?
        end
      end
    end
  end
end
