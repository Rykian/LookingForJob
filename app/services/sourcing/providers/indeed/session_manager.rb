# frozen_string_literal: true

module Sourcing
  module Providers
    module Indeed
      class SessionNotFoundError < StandardError
        def initialize(msg = "Indeed session not found. Create data/indeed_session.json")
          super
        end
      end

      class SessionManager
        extend Sourcing::Providers::SessionManagerBase

        SESSION_PATH = Rails.root.join("data", "indeed_session.json").freeze
        REQUIRE_SESSION_ENV = "INDEED_REQUIRE_SESSION"
        NOT_FOUND_ERROR = SessionNotFoundError
        LOGIN_COMMAND = "bin/rails indeed:login"
      end
    end
  end
end
