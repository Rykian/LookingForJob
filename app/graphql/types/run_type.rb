# frozen_string_literal: true

module Types
  class RunType < Types::BaseObject
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

    # Batches per-run new/updated offer counts into a single SQL query.
    # "New" = JobOffer.created_at >= Run.created_at (row was born during/after the run).
    # "Updated" = JobOffer.created_at < Run.created_at (offer pre-existed when the run started).
    class RunOfferCounts < GraphQL::Dataloader::Source
      def fetch(run_ids)
        rows = ::RunJobOffer
          .joins(:run, :job_offer)
          .where(run_id: run_ids)
          .group(:run_id)
          .pluck(
            :run_id,
            Arel.sql("COUNT(*) FILTER (WHERE job_offers.created_at >= runs.created_at)"),
            Arel.sql("COUNT(*) FILTER (WHERE job_offers.created_at <  runs.created_at)")
          )
          .to_h { |id, new_n, upd_n| [id, { new: new_n, updated: upd_n }] }

        run_ids.map { |id| rows[id] || { new: 0, updated: 0 } }
      end
    end

    field :id, GraphQL::Types::ID, null: false
    field :keywords, [String], null: false
    field :providers, [String], null: false
    field :work_modes, [String], null: false
    field :job_offers_count, Integer, null: false
    field :new_offers_count, Integer, null: false,
      description: "Offers first discovered during this run (job_offers.created_at >= runs.created_at)."
    field :updated_offers_count, Integer, null: false,
      description: "Offers that pre-existed when this run started and were re-discovered."
    field :error_count, Integer, null: false,
      description: "Number of unresolved pipeline errors recorded for this run."
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def job_offers_count
      object.run_job_offers.size
    end

    def new_offers_count
      offer_counts.fetch(:new)
    end

    def updated_offers_count
      offer_counts.fetch(:updated)
    end

    def error_count
      dataloader.with(PipelineErrorCountByRun, resolved: false).load(object.id)
    end

    private

    def offer_counts
      @offer_counts ||= dataloader.with(RunOfferCounts).load(object.id)
    end
  end
end
