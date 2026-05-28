# frozen_string_literal: true

module Sourcing
  module Providers
    module Wttj
      class SessionNotFoundError < StandardError
        def initialize(msg = "WTTJ session not found. Run: bin/rails wttj:login")
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
