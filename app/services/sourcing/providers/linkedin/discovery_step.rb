require "uri"

module Sourcing
  module Providers
    module Linkedin
      class DiscoveryStep < Sourcing::DiscoveryStep
        PAGE_SIZE = 25

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
          has_next_page = discovered_urls.size >= PAGE_SIZE

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

          query = URI.encode_www_form_component(keyword)
          url = "https://www.linkedin.com/jobs/search/?keywords=#{query}&start=#{(page - 1) * PAGE_SIZE}"

          result = { discovered_urls: [], has_next_page: false }

          session = Sourcing::Providers::Linkedin::SessionManager.load

          Playwright.create(playwright_cli_executable_path: "npx playwright") do |playwright|
            browser = playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
            context = browser.new_context(storageState: session)
            page_obj = context.new_page
            page_obj.goto(url, waitUntil: "domcontentloaded")
            page_obj.wait_for_timeout(1200)

            hrefs = page_obj.eval_on_selector_all(
              "a[href*='/jobs/view/']",
              "elements => elements.map((el) => el.href).filter(Boolean)"
            )

            result[:discovered_urls] = Array(hrefs).uniq

            context.close
            browser.close
          end

          result
        rescue Sourcing::Providers::Linkedin::SessionNotFoundError
          raise
        rescue StandardError => e
          raise "LinkedIn discovery failed for source=#{source} work_mode=#{work_mode} page=#{page}: #{e.message}"
        end
      end
    end
  end
end
