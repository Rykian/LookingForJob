# frozen_string_literal: true

module Types
  class RunType < Types::BaseObject
    field :id, GraphQL::Types::ID, null: false
    field :keywords, [String], null: false
    field :providers, [String], null: false
    field :work_modes, [String], null: false
    field :job_offers_count, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def job_offers_count
      object.run_job_offers.size
    end
  end
end
