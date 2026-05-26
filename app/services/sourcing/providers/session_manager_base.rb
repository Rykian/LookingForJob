# frozen_string_literal: true

require "json"

module Sourcing
  module Providers
    # Shared class-method logic for provider SessionManager classes.
    # Extend this module in each provider's SessionManager and define:
    #   SESSION_PATH       - Pathname to the session JSON file
    #   REQUIRE_SESSION_ENV - env var name that gates strict mode (e.g. "INDEED_REQUIRE_SESSION")
    #   NOT_FOUND_ERROR    - the provider-specific SessionNotFoundError subclass
    #   LOGIN_COMMAND      - rake task shown in the "run X" guidance string
    module SessionManagerBase
      REQUIRED_ROOT_KEYS = %w[cookies origins].freeze

      def path = self::SESSION_PATH
      def exists? = File.exist?(path)
      def require_session? = ENV.fetch(self::REQUIRE_SESSION_ENV, "false") == "true"

      def save(storage_state)
        validate_storage_state!(storage_state)
        File.write(path, JSON.generate(storage_state))
      end

      def load
        raise self::NOT_FOUND_ERROR unless exists?

        storage_state = JSON.parse(File.read(path))
        validate_storage_state!(storage_state)
        storage_state
      rescue JSON::ParserError
        raise self::NOT_FOUND_ERROR, "Session file is invalid JSON at #{path}"
      end

      def validate_storage_state!(storage_state)
        raise self::NOT_FOUND_ERROR, "Session file is invalid at #{path}" unless storage_state.is_a?(Hash)

        missing_keys = REQUIRED_ROOT_KEYS.reject { |key| storage_state.key?(key) }
        if missing_keys.any?
          raise self::NOT_FOUND_ERROR, "Session file is missing #{missing_keys.join(", ")} at #{path}"
        end

        unless storage_state["cookies"].is_a?(Array) && storage_state["origins"].is_a?(Array)
          raise self::NOT_FOUND_ERROR, "Session file is invalid at #{path}"
        end

        true
      end

      def load_if_exists
        return nil unless exists?

        load
      end

      def load_if_required!
        session = load_if_exists
        return session unless require_session?
        return session if session

        raise self::NOT_FOUND_ERROR, "Trusted session required. Run: #{self::LOGIN_COMMAND}"
      end

      def clear
        File.delete(path) if exists?
      end
    end
  end
end
