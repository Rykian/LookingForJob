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
              fetch_step:     Sourcing::Providers::Wttj::FetchStep.new,
              analyze_step:   Sourcing::Providers::Wttj::AnalyzeStep.new,
              enrich_step:    Sourcing::Providers::Wttj::EnrichStep.new
            )
          )

          registry.register(
            "france_travail",
            Provider.new(
              discovery_step: Sourcing::Providers::FranceTravail::DiscoveryStep.new,
              fetch_step:     Sourcing::Providers::FranceTravail::FetchStep.new,
              analyze_step:   Sourcing::Providers::FranceTravail::AnalyzeStep.new,
              enrich_step:    Sourcing::Providers::FranceTravail::EnrichStep.new
            )
          )

          registry.register(
            "cadremploi",
            Provider.new(
              discovery_step: Sourcing::Providers::Cadremploi::DiscoveryStep.new,
              fetch_step:     Sourcing::Providers::Cadremploi::FetchStep.new,
              analyze_step:   Sourcing::Providers::Cadremploi::AnalyzeStep.new,
              enrich_step:    Sourcing::Providers::Cadremploi::EnrichStep.new
            )
          )

          registry.register(
            "hellowork",
            Provider.new(
              discovery_step: Sourcing::Providers::Hellowork::DiscoveryStep.new,
              fetch_step:     Sourcing::Providers::Hellowork::FetchStep.new,
              analyze_step:   Sourcing::Providers::Hellowork::AnalyzeStep.new,
              enrich_step:    Sourcing::Providers::Hellowork::EnrichStep.new
            )
          )

          registry.register(
            "apec",
            Provider.new(
              discovery_step: Sourcing::Providers::Apec::DiscoveryStep.new,
              fetch_step:     Sourcing::Providers::Apec::FetchStep.new,
              analyze_step:   Sourcing::Providers::Apec::AnalyzeStep.new,
              enrich_step:    Sourcing::Providers::Apec::EnrichStep.new
            )
          )

          registry.register(
            "indeed",
            Provider.new(
              discovery_step: Sourcing::Providers::Indeed::DiscoveryStep.new,
              fetch_step:     Sourcing::Providers::Indeed::FetchStep.new,
              analyze_step:   Sourcing::Providers::Indeed::AnalyzeStep.new,
              enrich_step:    Sourcing::Providers::Indeed::EnrichStep.new
            )
          )

          registry.register(
            "welovedevs",
            Provider.new(
              discovery_step: Sourcing::Providers::Welovedevs::DiscoveryStep.new,
              fetch_step:     Sourcing::Providers::Welovedevs::FetchStep.new,
              analyze_step:   Sourcing::Providers::Welovedevs::AnalyzeStep.new,
              enrich_step:    Sourcing::Providers::Welovedevs::EnrichStep.new
            )
          )

          registry.register(
            "collective_work",
            Provider.new(
              discovery_step: Sourcing::Providers::CollectiveWork::DiscoveryStep.new,
              fetch_step:     Sourcing::Providers::CollectiveWork::FetchStep.new,
              analyze_step:   Sourcing::Providers::CollectiveWork::AnalyzeStep.new,
              enrich_step:    Sourcing::Providers::CollectiveWork::EnrichStep.new
            )
          )

        registry
      end
    end
  end
end
