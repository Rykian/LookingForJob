# frozen_string_literal: true

module Types
  class StepsDetailsType < Types::BaseObject
    description "Per-step completion metadata for a job offer pipeline."

    field :discovery, Types::StepDetailType, null: true, hash_key: "discovery"
    field :fetch, Types::StepDetailType, null: true, hash_key: "fetch"
    field :analyze, Types::StepDetailType, null: true, hash_key: "analyze"
    field :enrich, Types::StepDetailType, null: true, hash_key: "enrich"
    field :score, Types::StepDetailType, null: true, hash_key: "score"
  end
end
