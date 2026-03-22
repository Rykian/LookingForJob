require "uri"

module Sourcing
  module Providers
    module Linkedin
      class DiscoveryStep < Sourcing::DiscoveryStep
        PAGE_SIZE = 25
        MAX_PAGES = 10
        JOB_CARD_SELECTOR = "li.scaffold-layout__list-item[data-occludable-job-id]"
        JOB_LINK_SELECTOR = "a[href*='/jobs/view/']"
        NEXT_PAGE_SELECTORS = [
          "button[aria-label*='Next']",
          "button[aria-label*='Suivant']",
          "button.jobs-search-pagination__button--next"
        ].freeze

        def initialize(crawler: nil)
          @crawler = crawler || method(:crawl_with_playwright)
        end

        def call(input)
          source = input.fetch(:source)
          keyword = input.fetch(:keyword)
          work_mode = input.fetch(:work_mode)
          page = Integer(input.fetch(:page))

          crawled = @crawler.call(
            source: source,
            keyword: keyword,
            work_mode: work_mode,
            page: page
          )

          discovered_urls = Array(crawled[:discovered_urls]).map { |u| clean_url(u) }.uniq
          # Use next-page button state when the real crawler provides it;
          # fall back to count-based heuristic for test doubles.
          has_next_page = crawled.fetch(:has_next_page, discovered_urls.any? && page < MAX_PAGES)

          {
            discovered_urls: discovered_urls,
            has_next_page: has_next_page,
            next_job_data: has_next_page ? {
              source: source,
              keyword: keyword,
              work_mode: work_mode,
              page: page + 1
            } : nil
          }
        end

        def clean_url(url)
          uri = URI.parse(url)
          uri.query = nil
          uri.fragment = nil
          uri.to_s
        end

        def crawl_with_playwright(source:, keyword:, work_mode:, page:)
          require "playwright"

          url = build_search_url(keyword: keyword, work_mode: work_mode, page: page)

          result = { discovered_urls: [], has_next_page: false }

          session = Sourcing::Providers::Linkedin::SessionManager.load

          Playwright.create(playwright_cli_executable_path: "npx playwright") do |playwright|
            browser = playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
            context = browser.new_context(storageState: session)
            page_obj = context.new_page
            page_obj.goto(url, waitUntil: "domcontentloaded")

            cards_found = begin
              page_obj.wait_for_selector(JOB_CARD_SELECTOR, timeout: 15_000, state: "attached")
              true
            rescue => e
              Rails.logger.warn("LinkedIn discovery: no job cards for source=#{source} page=#{page}: #{e.message}")
              false
            end

            if cards_found
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
            end

            context.close
            browser.close
          end

          result
        rescue Sourcing::Providers::Linkedin::SessionNotFoundError
          raise
        rescue StandardError => e
          raise "LinkedIn discovery failed for source=#{source} work_mode=#{work_mode} page=#{page}: #{e.message}"
        end

        def build_search_url(keyword:, work_mode:, page:)
          params = {
            keywords: keyword,
            start: (page - 1) * PAGE_SIZE
          }

          # LinkedIn remote/hybrid filter (f_WT) is passed from WORK_MODE.
          params[:f_WT] = work_mode if work_mode && !work_mode.to_s.strip.empty?

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
