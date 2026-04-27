# frozen_string_literal: true

require "json"

module Sourcing
  module Providers
    module Cadremploi
      class SessionNotFoundError < StandardError
        def initialize(msg = "Cadremploi session not found. Create data/cadremploi_session.json")
          super
        end
      end

      class SessionManager
        SESSION_PATH = Rails.root.join("data", "cadremploi_session.json").freeze
        REQUIRED_ROOT_KEYS = %w[cookies origins].freeze

        def self.path
          SESSION_PATH
        end

        def self.exists?
          File.exist?(SESSION_PATH)
        end

        def self.require_session?
          ENV.fetch("CADREMPLOI_REQUIRE_SESSION", "false") == "true"
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
          raise SessionNotFoundError, "Cadremploi session file is invalid JSON at #{SESSION_PATH}"
        end

        def self.validate_storage_state!(storage_state)
          unless storage_state.is_a?(Hash)
            raise SessionNotFoundError, "Cadremploi session file is invalid at #{SESSION_PATH}"
          end

          missing_keys = REQUIRED_ROOT_KEYS.reject { |key| storage_state.key?(key) }
          if missing_keys.any?
            raise SessionNotFoundError,
                  "Cadremploi session file is invalid: missing #{missing_keys.join(', ')} at #{path}"
          end

          unless storage_state["cookies"].is_a?(Array) && storage_state["origins"].is_a?(Array)
            raise SessionNotFoundError, "Cadremploi session file is invalid at #{path}"
          end

          true
        end

        def self.load_if_exists
          return nil unless exists?

          load
        end

        def self.load_if_required!
          session = load_if_exists
          return session unless require_session?

          return session if session

          raise SessionNotFoundError, "Cadremploi trusted session required. Run: bin/rails cadremploi:login"
        end

        def self.clear
          File.delete(path) if exists?
        end
      end
    end
  end
end
