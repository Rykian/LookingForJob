module Sourcing
  class EnrichStep
    def call(input)
      raise NotImplementedError, "Sourcing::EnrichStep is a contract"
    end
  end
end
