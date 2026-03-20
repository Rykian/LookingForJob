module Sourcing
  class DiscoveryStep
    def call(input)
      raise NotImplementedError, "Sourcing::DiscoveryStep must be implemented"
    end
  end
end
