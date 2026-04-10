module Sourcing
  module Providers
    module Cadremploi
      class SessionValidationError < StandardError
        def initialize(msg = "Cadremploi session validation failed. Run: bin/rails cadremploi:login")
          super
        end
      end

      class SessionValidator
        include Sourcing::PlaywrightSupport

        VALIDATION_URL = "https://www.cadremploi.fr/emploi/liste_offres?motsCles=developpeur".freeze
        BLOCKED_URL_PATTERN = %r{/(cdn-cgi/challenge-platform|challenge|captcha|login)(/|\?|$)}i
        BLOCKED_TITLE_PATTERN = /(cloudflare|captcha|verification|verify you are human|security check)/i

        def initialize(storage_state:, validation_runner: nil)
          @storage_state = storage_state
          @validation_runner = validation_runner
        end

        def validate!
          SessionManager.validate_storage_state!(@storage_state)

          validation_runner.call(@storage_state) do |page_obj|
            validate_page!(page_obj)
          end

          true
        rescue SessionNotFoundError => e
          raise SessionValidationError, e.message.sub("not found", "validation failed")
        rescue SessionValidationError
          raise
        rescue StandardError => e
          raise SessionValidationError, "Cadremploi session validation failed: #{e.message}"
        end

        private

        def validation_runner
          @validation_runner ||= lambda do |storage_state, &block|
            with_playwright_page(url: VALIDATION_URL, locale: "fr-FR", storage_state: storage_state, &block)
          end
        end

        def validate_page!(page_obj)
          page_obj.wait_for_timeout(1_000)

          current_url = page_obj.url.to_s
          title = page_obj.title.to_s
          markers = page_obj.evaluate(<<~JS)
            () => {
              const challengeContainer = !!document.querySelector('[id*="challenge"], [class*="challenge"], [class*="captcha"], iframe[src*="captcha"], iframe[src*="challenge"]');
              const hasBlockingOverlay = !!document.querySelector('[id*="cf-chl"], [class*="cf-challenge"], [data-testid*="captcha"]');
              const hasJobList = !!document.querySelector('main, .search-results, [href*="detail_offre"], [class*="offer"]');

              return {
                challengeContainer,
                hasBlockingOverlay,
                hasJobList,
              };
            }
          JS

          if blocked_page?(current_url: current_url, title: title, markers: markers)
            raise SessionValidationError,
                  "Cadremploi session validation reached challenge_or_login_page for current_url=#{current_url} title=#{title.inspect}"
          end

          true
        end

        def blocked_page?(current_url:, title:, markers:)
          normalized_url = current_url.to_s
          normalized_title = title.to_s
          marker_hash = markers.is_a?(Hash) ? markers : {}
          challenge_container = marker_hash["challengeContainer"] || marker_hash[:challengeContainer]
          has_blocking_overlay = marker_hash["hasBlockingOverlay"] || marker_hash[:hasBlockingOverlay]
          has_job_list = marker_hash["hasJobList"] || marker_hash[:hasJobList]

          return true if normalized_url.match?(BLOCKED_URL_PATTERN)
          return true if normalized_title.match?(BLOCKED_TITLE_PATTERN)
          return true if challenge_container || has_blocking_overlay
          return true unless has_job_list

          false
        end
      end
    end
  end
end
