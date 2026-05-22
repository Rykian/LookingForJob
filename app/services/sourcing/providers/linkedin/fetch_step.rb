# frozen_string_literal: true

require "faraday"
require "faraday-cookie_jar"

module Sourcing
  module Providers
    module Linkedin
      # Raised when LinkedIn fetch produces unusable content (removed offer, blank, shell HTML,
      # or missing the required title marker). Referenced by Sourcing::FetchJob for blank-content
      # diagnostics and by spec/jobs/sourcing/fetch_job_spec.rb.
      class FetchContentError < StandardError; end

      # Fetches a single LinkedIn job offer via the public guest API.
      # Endpoint: https://www.linkedin.com/jobs-guest/jobs/api/jobPosting/<id>
      class FetchStep < Sourcing::FetchStep
        VERSION = 2

        DETAIL_URL = "https://www.linkedin.com/jobs-guest/jobs/api/jobPosting"
        USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                     "(KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
        ACCEPT_LANGUAGE = "fr-FR,fr;q=0.9,en;q=0.8"
        TITLE_MARKER = "top-card-layout__title"
        REQUEST_DELAY_RANGE = (1.5..3.0).freeze

        def initialize(connection: nil)
          super(fetcher: nil)
          @injected_connection = connection
        end

        protected

        def fetch_page(url:)
          job_id = extract_job_id(url)
          raise FetchContentError, "LinkedIn: could not extract job id from url=#{url}" unless job_id

          throttle!
          response = connection.get("#{DETAIL_URL}/#{job_id}")
          html = response.body.to_s

          case response.status
          when 200
            ensure_basic_html_content!(provider_name: "LinkedIn", url: url, html: html)
            unless html.include?(TITLE_MARKER)
              raise FetchContentError,
                    "LinkedIn fetch returned HTML without top-card title marker (auth wall or selector drift) for url=#{url}"
            end
            html
          when 404, 410
            raise FetchContentError,
                  "LinkedIn job removed or unavailable (HTTP #{response.status}) for url=#{url}"
          when 403, 429
            raise "LinkedIn rate-limited or blocked (HTTP #{response.status}) for url=#{url}; back off the IP or rotate egress"
          else
            raise "LinkedIn fetch returned HTTP #{response.status} for url=#{url}"
          end
        end

        private

        def connection
          @connection ||= @injected_connection || Faraday.new do |conn|
            conn.headers["User-Agent"] = USER_AGENT
            conn.headers["Accept"] = "text/html,*/*"
            conn.headers["Accept-Language"] = ACCEPT_LANGUAGE
            conn.use :cookie_jar
            conn.adapter Faraday.default_adapter
            conn.options.timeout = 15
            conn.options.open_timeout = 5
          end
        end

        # Jittered pause between LinkedIn requests. Only sleeps the remaining
        # portion of the window since the last call, so widely-spaced Sidekiq
        # jobs don't all eat a full delay. Stubbed in specs.
        def throttle!
          target = rand(REQUEST_DELAY_RANGE)
          if @last_request_at
            elapsed = Time.now - @last_request_at
            remaining = target - elapsed
            sleep(remaining) if remaining.positive?
          end
          @last_request_at = Time.now
        end

        def extract_job_id(url)
          return nil if url.to_s.empty?
          return Regexp.last_match(1) if url =~ %r{/jobs/view/(?:[^/]*-)?(\d+)}

          nil
        end
      end
    end
  end
end
