module Sourcing
  module Providers
    module Linkedin
      class FetchStep < Sourcing::FetchStep
        def initialize(fetcher: nil)
          @fetcher = fetcher || method(:fetch_with_playwright)
        end

        def call(input)
          url = input.fetch(:url)
          @fetcher.call(url: url)
        end

        private

        def fetch_with_playwright(url:)
          require "playwright"

          html = nil

          session = Sourcing::Providers::Linkedin::SessionManager.load

          Playwright.create(playwright_cli_executable_path: "npx playwright") do |playwright|
            browser = playwright.chromium.launch(headless: ENV.fetch("HEADLESS", "true") == "true")
            context = browser.new_context(storageState: session)
            page_obj = context.new_page
            page_obj.goto(url, waitUntil: "domcontentloaded")
            page_obj.wait_for_timeout(1000)
            html = page_obj.content
            context.close
            browser.close
          end

          html
        end
      end
    end
  end
end
