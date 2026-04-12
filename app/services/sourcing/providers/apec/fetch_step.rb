# frozen_string_literal: true

module Sourcing
  module Providers
    module Apec
      class FetchStep < Sourcing::FetchStep
        VERSION = 1

        MAIN_CONTENT_SELECTORS = [
          "h1",
          "apec-offre-metadata",
          ".details-post",
        ].freeze

        BLOCKED_PAGE_PATTERN = /(cloudflare|captcha|challenge|access denied|forbidden|verify you are human|robot)/i
        INVALID_PAGE_PATTERN = /(offre non disponible|offre expir[ée]e|page non trouv[ée]e|erreur 404|not found)/i
        MIN_BODY_TEXT_LENGTH = 600
        MIN_DETAILS_BLOCK_COUNT = 4

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
            raise "Apec fetch found no main content markers for #{url}" unless found

            html = page_obj.content
            ensure_basic_html_content!(provider_name: "Apec", url: url, html: html)
            ensure_valid_job_page!(page_obj: page_obj, url: url, html: html)
            html
          end
        end

        def ensure_valid_job_page!(page_obj:, url:, html:)
          title = page_obj.title.to_s
          current_url = page_obj.url.to_s
          body_text_length = page_obj.evaluate("() => ((document.body && document.body.innerText) || '').trim().length").to_i
          details_count = page_obj.evaluate("() => document.querySelectorAll('.details-post').length").to_i
          metadata_text = page_obj.evaluate("() => (document.querySelector('apec-offre-metadata')?.innerText || '')").to_s
          payload = "#{title} #{current_url} #{metadata_text}"

          if payload.match?(BLOCKED_PAGE_PATTERN)
            raise "Apec returned an anti-bot challenge for #{url} current_url=#{current_url}"
          end

          if payload.match?(INVALID_PAGE_PATTERN)
            raise "Apec fetch resolved to a non-job page for #{url} title=#{title.inspect}"
          end

          unless current_url.match?(%r{/emploi/detail-offre/\d+[A-Z]?})
            raise "Apec fetch resolved to unexpected URL for #{url}: #{current_url}"
          end

          unless metadata_text.match?(/Ref\. Apec/i)
            raise "Apec fetch missing offer metadata for #{url}"
          end

          if details_count < MIN_DETAILS_BLOCK_COUNT
            raise "Apec fetch produced too few detail blocks for #{url}: details_count=#{details_count}"
          end

          if body_text_length < MIN_BODY_TEXT_LENGTH
            raise "Apec fetch produced suspiciously small page body for #{url}: body_text_length=#{body_text_length} html_length=#{html.to_s.length}"
          end
        end
      end
    end
  end
end
