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

        NOT_FOUND_ERROR = SessionNotFoundError
      end
    end
  end
end
