# frozen_string_literal: true

require "faraday"
require "faraday-cookie_jar"
require "nokogiri"
require "uri"

module Sourcing
  module Providers
    module Linkedin
      # Discovers LinkedIn job URLs via the public guest API.
      # No authentication, no Playwright. Pure HTTP + DOM parsing.
      #
      # Endpoint: https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search
      # Returns an HTML fragment with 10 job cards per call, paginated by `start=`.
      class DiscoveryStep < Sourcing::DiscoveryStep
        VERSION = 1

        SEARCH_URL = "https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search"
        RESULTS_PER_PAGE = 10
        MAX_PAGES = 40
        DEFAULT_LOCATION = "France"
        USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                     "(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
        ACCEPT_LANGUAGE = "fr-FR,fr;q=0.9,en;q=0.8"
        REQUEST_DELAY_RANGE = (1.5..3.0).freeze

        # LinkedIn work-type filter param (f_WT): 1=onsite, 2=remote, 3=hybrid.
        WORK_MODE_PARAM = {
          "onsite"  => "1",
          "on-site" => "1",
          "remote"  => "2",
          "hybrid"  => "3",
        }.freeze

        def initialize(connection: nil)
          @injected_connection = connection
        end

        def setup(input:)
          # No Playwright runtime — guest endpoints serve full content over plain HTTP.
          # Returning a hash keeps the contract intact with DiscoveryStep base class.
          { connection: build_connection }
        end

        def crawl_page(input:, runtime:, page:)
          connection = runtime.fetch(:connection)
          throttle! if page > 1
          url = build_search_url(keyword: input[:keyword], work_mode: input[:work_mode], page: page)
          Rails.logger.info("LinkedIn Discovery: GET #{url}")

          response = connection.get(url)
          raise "LinkedIn discovery returned HTTP #{response.status} for #{url}" unless response.success?

          discovered_urls = extract_urls(response.body.to_s)
          Rails.logger.info("LinkedIn Discovery: page=#{page} found=#{discovered_urls.size}")

          {
            discovered_urls: discovered_urls,
            has_next_page: !discovered_urls.empty? && page < MAX_PAGES,
          }
        end

        def teardown(runtime:)
          # Faraday connections don't require explicit teardown.
        end

        private

        def build_connection
          @injected_connection || Faraday.new do |conn|
            conn.headers["User-Agent"] = USER_AGENT
            conn.headers["Accept"] = "text/html,*/*"
            conn.headers["Accept-Language"] = ACCEPT_LANGUAGE
            conn.use :cookie_jar
            conn.adapter Faraday.default_adapter
            conn.options.timeout = 15
            conn.options.open_timeout = 5
          end
        end

        # Jittered pause between LinkedIn requests to stay under guest-endpoint
        # rate limits. Stubbed in specs.
        def throttle!
          sleep(rand(REQUEST_DELAY_RANGE))
        end

        def build_search_url(keyword:, work_mode:, page:)
          start = [(page.to_i - 1) * RESULTS_PER_PAGE, 0].max
          params = {
            "keywords" => keyword.to_s,
            "location" => DEFAULT_LOCATION,
            "start"    => start.to_s,
          }
          if (wt = WORK_MODE_PARAM[work_mode.to_s.downcase])
            params["f_WT"] = wt
          end
          "#{SEARCH_URL}?#{URI.encode_www_form(params)}"
        end

        def extract_urls(body)
          doc = Nokogiri::HTML.fragment(body)
          doc.css("a.base-card__full-link, a.job-search-card__title")
             .filter_map { |a| canonicalize(a["href"]) }
             .uniq
        end

        def canonicalize(href)
          return nil if href.nil? || href.empty?

          uri = URI.parse(href)
          # LinkedIn job paths: /jobs/view/<slug>-<id>?... or /jobs/view/<id>/
          return nil unless uri.path =~ %r{/jobs/view/(?:[^/]*-)?(\d+)/?\z}

          "https://www.linkedin.com/jobs/view/#{Regexp.last_match(1)}/"
        rescue URI::InvalidURIError
          nil
        end
      end
    end
  end
end
