module Sourcing
  class AnalyzeStep
    def call(input)
      raise NotImplementedError, "Sourcing::AnalyzeStep must be implemented"
    end
  end
end
