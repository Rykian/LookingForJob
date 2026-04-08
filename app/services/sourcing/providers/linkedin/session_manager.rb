require "json"

module Sourcing
  module Providers
    module Linkedin
      class SessionNotFoundError < StandardError
        def initialize(msg = "LinkedIn session not found. Run: bin/rails linkedin:login")
          super
        end
      end

      class SessionManager
        SESSION_PATH = Rails.root.join("data", "linkedin_session.json").freeze
        REQUIRED_ROOT_KEYS = %w[cookies origins].freeze
        AUTH_COOKIE_NAME = "li_at".freeze

        def self.exists?
          File.exist?(SESSION_PATH)
        end

        def self.save(storage_state)
          validate_storage_state!(storage_state)
          File.write(SESSION_PATH, JSON.generate(storage_state))
        end

        def self.load
          raise SessionNotFoundError unless exists?

          storage_state = JSON.parse(File.read(SESSION_PATH))
          validate_storage_state!(storage_state)
          storage_state
        rescue JSON::ParserError
          raise SessionNotFoundError, "LinkedIn session file is corrupt. Run: bin/rails linkedin:login"
        end

        def self.validate_storage_state!(storage_state)
          unless storage_state.is_a?(Hash)
            raise SessionNotFoundError, "LinkedIn session file is invalid. Run: bin/rails linkedin:login"
          end

          missing_keys = REQUIRED_ROOT_KEYS.reject { |key| storage_state.key?(key) }
          if missing_keys.any?
            raise SessionNotFoundError,
                  "LinkedIn session file is invalid: missing #{missing_keys.join(', ')}. Run: bin/rails linkedin:login"
          end

          unless storage_state["cookies"].is_a?(Array) && storage_state["origins"].is_a?(Array)
            raise SessionNotFoundError, "LinkedIn session file is invalid. Run: bin/rails linkedin:login"
          end

          true
        end

        def self.authenticated_storage_state?(storage_state)
          Array(storage_state["cookies"]).any? do |cookie|
            cookie.is_a?(Hash) && cookie["name"] == AUTH_COOKIE_NAME && cookie["value"].to_s.strip != ""
          end
        end

        def self.clear
          File.delete(SESSION_PATH) if exists?
        end
      end
    end
  end
end
