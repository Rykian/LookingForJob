# frozen_string_literal: true

module Types
  class RunType < Types::BaseObject
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
      dataloader.with(Sources::PipelineErrorCountByRun, resolved: false).load(object.id)
    end

    private

    def offer_counts
      @offer_counts ||= dataloader.with(Sources::RunOfferCounts).load(object.id)
    end
  end
end
