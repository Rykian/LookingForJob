module Sourcing
  module Pipeline
    # Ordered per-offer pipeline. Each entry resolves the current VERSION for an
    # offer's provider and points at the job that runs that step. Order matters:
    # advance walks the list in sequence and enqueues the first outdated step.
    STEPS = [
      {
        name: "fetch",
        job: Sourcing::FetchJob,
        version: ->(provider) { provider.fetch_step.class::VERSION },
      },
      {
        name: "analyze",
        job: Sourcing::AnalyzeJob,
        version: ->(provider) { provider.analyze_step.class::VERSION },
      },
      {
        name: "enrich",
        job: Sourcing::EnrichJob,
        version: ->(provider) { provider.enrich_step.class::VERSION },
      },
      {
        name: "score",
        job: Sourcing::ScoringJob,
        version: ->(_provider) { Sourcing::ScoreStep::VERSION },
      },
    ].freeze

    module_function

    # Enqueue the first step whose stored version differs from the current
    # VERSION. Returns the step name that was enqueued, or nil when the offer is
    # already current. force is forwarded to the enqueued job; it does not
    # affect step selection (a step is only enqueued when it's outdated).
    def advance(offer, force: false)
      provider = Sourcing::Providers.registry.fetch(offer.source)
      step = STEPS.find { |s| outdated?(offer, s, provider) }
      return nil unless step

      step[:job].perform_later(offer.id, source: offer.source, force: force)
      step[:name]
    end

    # True when the offer's stored version for step_name matches the current
    # VERSION and force is false — i.e. the step has nothing to do.
    def should_skip?(offer, step_name, force:)
      return false if force

      provider = Sourcing::Providers.registry.fetch(offer.source)
      !outdated?(offer, step_for(step_name), provider)
    end

    def step_for(step_name)
      STEPS.find { |s| s[:name] == step_name } || raise(ArgumentError, "Unknown step: #{step_name}")
    end

    def outdated?(offer, step, provider)
      offer.steps_details.dig(step[:name], "version") != step[:version].call(provider)
    end
  end
end
