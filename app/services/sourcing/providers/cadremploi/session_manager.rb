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

        NOT_FOUND_ERROR = SessionNotFoundError
      end
    end
  end
end
