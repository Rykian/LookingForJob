module Sourcing
  class FetchStep
    include PlaywrightSupport

    def call(input)
      raise NotImplementedError, "Sourcing::FetchStep must be implemented"
    end
  end
end
