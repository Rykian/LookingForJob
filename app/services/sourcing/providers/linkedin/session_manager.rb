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

        def self.exists?
          File.exist?(SESSION_PATH)
        end

        def self.save(storage_state)
          File.write(SESSION_PATH, JSON.generate(storage_state))
        end

        def self.load
          raise SessionNotFoundError unless exists?

          JSON.parse(File.read(SESSION_PATH))
        rescue JSON::ParserError
          raise SessionNotFoundError, "LinkedIn session file is corrupt. Run: bin/rails linkedin:login"
        end

        def self.clear
          File.delete(SESSION_PATH) if exists?
        end
      end
    end
  end
end
