# frozen_string_literal: true

module Sources
  # Batches PipelineError count lookups by run_id. Each unique resolved
  # status group resolves all requested run ids with a single GROUP BY query
  # regardless of how many runs reference it in the same GraphQL query.
  class PipelineErrorCountByRun < GraphQL::Dataloader::Source
    def initialize(resolved: false)
      @resolved = resolved
    end

    def fetch(run_ids)
      counts = ::PipelineError
        .where(run_id: run_ids, resolved: @resolved)
        .group(:run_id)
        .count
      run_ids.map { |id| counts[id.to_i] || 0 }
    end
  end
end
