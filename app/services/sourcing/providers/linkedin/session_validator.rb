module Sourcing
  module Providers
    module Linkedin
      class SessionValidationError < StandardError
        def initialize(msg = "LinkedIn session validation failed. Run: bin/rails linkedin:login")
          super
        end
      end

      class SessionValidator
        include Sourcing::PlaywrightSupport

        VALIDATION_URL = "https://www.linkedin.com/feed/".freeze
        BLOCKED_URL_PATTERN = %r{/(checkpoint|challenge|captcha|authwall|uas/login|login)(/|\?|$)}i
        BLOCKED_TITLE_PATTERN = /(captcha|security verification|verify(ing)? you'?re human|are you a human)/i

        def initialize(storage_state:, validation_runner: nil)
          @storage_state = storage_state
          @validation_runner = validation_runner
        end

        def validate!
          SessionManager.validate_storage_state!(@storage_state)

          unless SessionManager.authenticated_storage_state?(@storage_state)
            raise SessionValidationError,
                  "LinkedIn session validation failed: missing li_at auth cookie. Run: bin/rails linkedin:login"
          end

          validation_runner.call(@storage_state) do |page_obj|
            validate_page!(page_obj)
          end

          true
        rescue SessionNotFoundError => e
          raise SessionValidationError, e.message.sub("not found", "validation failed")
        rescue SessionValidationError
          raise
        rescue StandardError => e
          raise SessionValidationError, "LinkedIn session validation failed: #{e.message}"
        end

        private

        def validation_runner
          @validation_runner ||= lambda do |storage_state, &block|
            with_playwright_page(url: VALIDATION_URL, locale: "en-US", storage_state: storage_state, &block)
          end
        end

        def validate_page!(page_obj)
          page_obj.wait_for_timeout(1_000)

          current_url = page_obj.url.to_s
          title = page_obj.title.to_s
          markers = page_obj.evaluate(<<~JS)
            () => {
              const loginForm = !!document.querySelector('form[action*="/uas/login"], input[type="password"], #username, #password');
              const challengeContainer = !!document.querySelector('[id*="challenge"], [class*="challenge"], [data-test-id*="captcha"], iframe[src*="captcha"]');
              const hasFeedContainer = !!document.querySelector('.feed-identity-module, .scaffold-layout, .feed-shared-update-v2, [data-view-name*="feed"]');

              return {
                loginForm,
                challengeContainer,
                hasFeedContainer,
              };
            }
          JS

          if blocked_page?(current_url: current_url, title: title, markers: markers)
            raise SessionValidationError,
                  "LinkedIn session validation reached login_or_challenge_page for current_url=#{current_url} title=#{title.inspect}"
          end

          true
        end

        def blocked_page?(current_url:, title:, markers:)
          normalized_url = current_url.to_s
          normalized_title = title.to_s
          marker_hash = markers.is_a?(Hash) ? markers : {}
          login_form = marker_hash["loginForm"] || marker_hash[:loginForm]
          challenge_container = marker_hash["challengeContainer"] || marker_hash[:challengeContainer]
          has_feed_container = marker_hash["hasFeedContainer"] || marker_hash[:hasFeedContainer]

          return true if normalized_url.match?(BLOCKED_URL_PATTERN)
          return true if normalized_title.match?(BLOCKED_TITLE_PATTERN)
          return true if challenge_container
          return true if login_form && !has_feed_container

          false
        end
      end
    end
  end
end
