module Sourcing
  module Providers
    module_function

    def registry
      @registry ||= begin
        registry = ProviderRegistry.new

        registry.register(
          "linkedin",
          Provider.new(
            discovery_step: Sourcing::Providers::Linkedin::DiscoveryStep.new,
            fetch_step: Sourcing::Providers::Linkedin::FetchStep.new,
            analyze_step: Sourcing::Providers::Linkedin::AnalyzeStep.new,
            enrich_step: Sourcing::Providers::Linkedin::EnrichStep.new
          )
        )

          registry.register(
            "wttj",
            Provider.new(
              discovery_step: Sourcing::Providers::Wttj::DiscoveryStep.new,
              fetch_step: Sourcing::Providers::Wttj::FetchStep.new,
              analyze_step: Sourcing::Providers::Wttj::AnalyzeStep.new,
              enrich_step: Sourcing::Providers::Wttj::EnrichStep.new
            )
          )

        registry
      end
    end
  end
end
