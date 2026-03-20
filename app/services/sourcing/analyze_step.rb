module Sourcing
  class AnalyzeStep
    def call(input)
      raise NotImplementedError, "Sourcing::AnalyzeStep is a contract"
    end
  end
end
