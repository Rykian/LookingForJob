# frozen_string_literal: true

module Sourcing
  module Providers
    module Cadremploi
      class SessionNotFoundError < StandardError
        def initialize(msg = "Cadremploi session not found. Create data/cadremploi_session.json")
          super
        end
      end

      class SessionManager
        extend Sourcing::Providers::SessionManagerBase

        SESSION_PATH = Rails.root.join("data", "cadremploi_session.json").freeze
        REQUIRE_SESSION_ENV = "CADREMPLOI_REQUIRE_SESSION"
        NOT_FOUND_ERROR = SessionNotFoundError
        LOGIN_COMMAND = "bin/rails cadremploi:login"
      end
    end
  end
end
