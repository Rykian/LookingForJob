# frozen_string_literal: true

require "json"

module Sourcing
  module Providers
    # Shared class-method logic for provider SessionManager classes.
    # Extend this module in each provider's SessionManager and define:
    #   NOT_FOUND_ERROR - the provider-specific SessionNotFoundError subclass
    #
    # path and login_command are derived automatically from the provider module name:
    #   Sourcing::Providers::Indeed::SessionManager → data/indeed_session.json, bin/rails indeed:login
    module SessionManagerBase
      REQUIRED_ROOT_KEYS = %w[cookies origins].freeze

      def provider_name
        # "Sourcing::Providers::Indeed::SessionManager" → "indeed"
        self.name.split("::")[2].downcase
      end

      def path
        Rails.root.join("data", "#{provider_name}_session.json")
      end

      def login_command
        "bin/rails #{provider_name}:login"
      end

      def exists? = File.exist?(path)

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

      def clear
        File.delete(path) if exists?
      end
    end
  end
end
