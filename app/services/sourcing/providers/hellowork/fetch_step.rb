# frozen_string_literal: true

module Sourcing
  module Providers
    module Hellowork
      class FetchStep < Sourcing::FetchStep
        VERSION = 1

        MAIN_CONTENT_SELECTORS = [
          "h1",
          "h2",
          "a[href*='/fr-fr/entreprises/']",
        ].freeze

        BLOCKED_PAGE_PATTERN = /(cloudflare|captcha|challenge|access denied|forbidden|verify you are human|robot)/i
        INVALID_PAGE_PATTERN = /(erreur 404|page non trouv[ée]e|not found)/i
        MIN_BODY_TEXT_LENGTH = 400

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
            found = wait_for_any_selector(
              page_obj: page_obj,
              selectors: MAIN_CONTENT_SELECTORS,
              timeout_ms: 7_000,
              wait_options: { state: "attached" }
            )
            raise "Hellowork fetch found no main content markers for #{url}" unless found

            html = page_obj.content
            ensure_basic_html_content!(provider_name: "Hellowork", url: url, html: html)
            ensure_valid_job_page!(page_obj: page_obj, url: url, html: html)
            html
          end
        end

        def ensure_valid_job_page!(page_obj:, url:, html:)
          title = page_obj.title.to_s
          current_url = page_obj.url.to_s
          body_text_length = page_obj.evaluate("() => ((document.body && document.body.innerText) || '').trim().length").to_i
          payload = "#{title} #{current_url}"

          if payload.match?(BLOCKED_PAGE_PATTERN)
            raise "Hellowork returned an anti-bot challenge for #{url} current_url=#{current_url}"
          end

          if payload.match?(INVALID_PAGE_PATTERN)
            raise "Hellowork fetch resolved to a non-job page for #{url} title=#{title.inspect}"
          end

          unless current_url.match?(%r{/fr-fr/emplois/\d+\.html})
            raise "Hellowork fetch resolved to unexpected URL for #{url}: #{current_url}"
          end

          if body_text_length < MIN_BODY_TEXT_LENGTH
            raise "Hellowork fetch produced suspiciously small page body for #{url}: body_text_length=#{body_text_length} html_length=#{html.to_s.length}"
          end
        end
      end
    end
  end
end
