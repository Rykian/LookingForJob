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
        name: "commute",
        job: Sourcing::CommuteJob,
        version: ->(_provider) { Sourcing::CommuteStep::VERSION },
      },
      {
        name: "score",
        job: Sourcing::ScoringJob,
        version: ->(_provider) { Sourcing::ScoreStep::VERSION },
      },
      {
        name: "company",
        job: Sourcing::CompanyJob,
        version: ->(_provider) { Sourcing::CompanyStep::VERSION },
      },
    ].freeze

    module_function

    # Enqueue the first step whose stored version differs from the current
    # VERSION. Returns the step name that was enqueued, or nil when the offer is
    # already current. force is forwarded to the enqueued job; it does not
    # affect step selection (a step is only enqueued when it's outdated).
    #
    # current_step: when supplied with only_forward: true, restricts the search
    # to steps after current_step. Jobs that call advance as a hand-off use this
    # to guarantee they never re-enqueue a step they just completed.
    def advance(offer, current_step, run_id, force: false, only_forward: true)
      if current_step
        PipelineError.where(job_offer_id: offer.id, step: current_step.to_s, resolved: false)
                     .update_all(resolved: true)
      end

      provider = Sourcing::Providers.registry.fetch(offer.source)

      steps = STEPS
      if only_forward && current_step
        idx = steps.index { |s| s[:name] == current_step.to_s }
        steps = steps[(idx + 1)..] if idx
      end

      step = steps.find { |s| outdated?(offer, s, provider) }
      return nil unless step

      step[:job].perform_later(offer.id, source: offer.source, force: force, run_id: run_id)
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
