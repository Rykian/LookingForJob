module Sourcing
  class FetchStep
    def call(input)
      raise NotImplementedError, "Sourcing::FetchStep must be implemented"
    end
  end
end
