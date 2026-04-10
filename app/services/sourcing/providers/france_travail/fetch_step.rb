require "cgi"

module Sourcing
  module Providers
    module FranceTravail
      class FetchStep < Sourcing::FetchStep
        VERSION = 1

        # Offer detail pages are server-rendered; wait for the schema.org description node.
        CONTENT_SELECTOR = "[itemprop='description']"

        def initialize(fetcher: nil)
          @fetcher = fetcher || method(:fetch_with_playwright)
        end

        def call(input)
          url = input.fetch(:url)
          @fetcher.call(url: url)
        end

        private

        def fetch_with_playwright(url:)
          with_playwright_page(url: url, locale: "fr-FR") do |page_obj|
            found = wait_for_any_selector(page_obj: page_obj, selectors: [CONTENT_SELECTOR], timeout_ms: 10_000)
            raise "FranceTravail fetch: content did not load for #{url}" unless found

            html = page_obj.content
            ensure_basic_html_content!(provider_name: "FranceTravail", url: url, html: html)
            html
          end
        end
      end
    end
  end
end
