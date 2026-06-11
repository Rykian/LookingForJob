# frozen_string_literal: true

require "faraday"
require "json"
require "uri"

module Sourcing
  module Providers
    module FreeWork
      # Discovers Free-Work job URLs from the public JSON API
      # (https://www.free-work.com/api/job_postings).
      #
      # Free-Work runs API Platform behind its Nuxt front; the same endpoints the site
      # consumes are open (no auth, no key, no anti-bot), so discovery is plain HTTP:
      # `GET /api/job_postings` with `Accept: application/ld+json` returns a hydra
      # collection (`hydra:member`, `hydra:totalItems`, `hydra:view` with `hydra:next`).
      #
      # Keyword filtering uses `searchKeywords=<keyword>` and work-mode filtering uses
      # `remoteMode=full|partial|none` — both verified to filter server-side. Pagination
      # uses `page=<N>` (1-indexed).
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 1

        BASE_URL = "https://www.free-work.com"
        API_PATH = "/api/job_postings"
        OFFER_URL_TEMPLATE = "#{BASE_URL}/fr/tech-it/%s/job-mission/%s".freeze
        DEFAULT_CATEGORY_SLUG = "consultant-fonctionnel"
        ITEMS_PER_PAGE = 30
        MAX_PAGES = 300 # safety cap: ~9000 offers at 30/page

        REMOTE_MODE_BY_WORK_MODE = {
          "remote"  => "full",
          "hybrid"  => "partial",
          "on-site" => "none",
        }.freeze

        def initialize(crawler: nil, connection: nil)
          @crawler = crawler
          @injected_connection = connection
        end

        def setup(input:)
          { mode: @crawler ? :crawler : :http }
        end

        def crawl_page(input:, runtime:, page:)
          return @crawler.call(input: input, runtime: runtime, page: page) if @crawler
          return { discovered_urls: [], has_next_page: false } if page > MAX_PAGES

          url = build_search_url(keyword: input[:keyword], work_mode: input[:work_mode], page: page)
          Rails.logger.info("FreeWork Discovery: GET #{url}")

          collection = fetch_collection(url)
          members = collection.fetch("hydra:member") do
            raise "no hydra:member in API response for #{url}"
          end

          discovered_urls = Array(members).filter_map { |member| offer_url(member) }
          has_next_page = collection.dig("hydra:view", "hydra:next").present?

          Rails.logger.info(
            "FreeWork Discovery: page=#{page} found=#{discovered_urls.size} total=#{collection["hydra:totalItems"]} next=#{has_next_page}"
          )

          { discovered_urls: discovered_urls, has_next_page: has_next_page }
        rescue StandardError => e
          raise "FreeWork crawl_page failed (page=#{page}): #{e.message}"
        end

        def teardown(runtime:)
          nil
        end

        private

        def build_search_url(keyword:, work_mode:, page:)
          params = { itemsPerPage: ITEMS_PER_PAGE }
          params[:searchKeywords] = keyword if keyword.to_s.strip.length.positive?

          remote_mode = REMOTE_MODE_BY_WORK_MODE[work_mode.to_s]
          params[:remoteMode] = remote_mode if remote_mode

          params[:page] = page if page.to_i > 1

          "#{BASE_URL}#{API_PATH}?#{URI.encode_www_form(params)}"
        end

        # Public detail URLs follow /fr/tech-it/<category-slug>/job-mission/<slug>.
        # FetchStep only relies on the trailing slug, so a missing category slug falls
        # back to a generic segment rather than dropping the offer.
        def offer_url(member)
          slug = member["slug"]
          return nil unless slug.is_a?(String) && !slug.empty?

          category_slug = member.dig("job", "nameForContributionSlug").presence || DEFAULT_CATEGORY_SLUG
          format(OFFER_URL_TEMPLATE, category_slug, slug)
        end

        def fetch_collection(url)
          response = connection.get(url)
          raise "HTTP #{response.status} for #{url}" unless response.success?

          data = JSON.parse(response.body)
          raise "unexpected API response shape (not a hydra collection) for #{url}" unless data.is_a?(Hash)

          data
        end

        def connection
          @injected_connection || Faraday.new do |f|
            f.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
            f.headers["Accept"] = "application/ld+json"
            f.headers["Accept-Language"] = "fr-FR,fr;q=0.9,en;q=0.8"
            f.options.timeout = 30
            f.options.open_timeout = 10
            f.adapter Faraday.default_adapter
          end
        end
      end
    end
  end
end
