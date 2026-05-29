# frozen_string_literal: true

module Types
  class RunType < Types::BaseObject
    field :id, GraphQL::Types::ID, null: false
    field :keywords, [String], null: false
    field :providers, [String], null: false
    field :work_modes, [String], null: false
    field :job_offers_count, Integer, null: false
    field :error_count, Integer, null: false,
      description: "Number of unresolved pipeline errors recorded for this run."
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def job_offers_count
      object.run_job_offers.size
    end

    def error_count
      dataloader.with(Sources::PipelineErrorCountByRun, resolved: false).load(object.id)
    end
  end
end
