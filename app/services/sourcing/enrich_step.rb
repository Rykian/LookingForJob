module Sourcing
  class EnrichStep
    def call(input)
      raise NotImplementedError, "Sourcing::EnrichStep must be implemented"
    end
  end
end
