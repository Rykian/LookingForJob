# frozen_string_literal: true

require "json"

module Sourcing
  module Providers
    module Cadremploi
      class SessionNotFoundError < StandardError
        def initialize(msg = "Cadremploi session not found. Set CADREMPLOI_STORAGE_STATE_PATH or create data/cadremploi_session.json")
          super
        end
      end

      class SessionManager
        SESSION_PATH = Rails.root.join("data", "cadremploi_session.json").freeze

        def self.path
          custom = ENV["CADREMPLOI_STORAGE_STATE_PATH"].to_s.strip
          return Pathname.new(custom) unless custom.empty?

          SESSION_PATH
        end

        def self.exists?
          File.exist?(path)
        end

        def self.require_session?
          ENV.fetch("CADREMPLOI_REQUIRE_SESSION", "false") == "true"
        end

        def self.save(storage_state)
          File.write(path, JSON.generate(storage_state))
        end

        def self.load
          raise SessionNotFoundError unless exists?

          JSON.parse(File.read(path))
        rescue JSON::ParserError
          raise SessionNotFoundError, "Cadremploi session file is invalid JSON at #{path}"
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
