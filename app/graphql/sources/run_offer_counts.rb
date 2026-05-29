# frozen_string_literal: true

module Sources
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
end
