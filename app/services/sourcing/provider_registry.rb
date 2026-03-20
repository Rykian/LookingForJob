module Sourcing
  Provider = Data.define(:discovery_step, :fetch_step, :analyze_step, :enrich_step)

  class ProviderRegistry
    def initialize
      @providers = {}
    end

    def register(source, provider)
      @providers[source.to_s] = provider
    end

    def fetch(source)
      @providers.fetch(source.to_s) do
        raise KeyError, "No sourcing provider registered for source=#{source.inspect}"
      end
    end
  end
end
