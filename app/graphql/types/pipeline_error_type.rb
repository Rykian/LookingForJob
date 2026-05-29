# frozen_string_literal: true

module Types
  class PipelineErrorType < Types::BaseObject
    field :id, ID, null: false
    field :job_offer_id, ID, null: true
    field :run_id, ID, null: true
    field :step, String, null: false
    field :source, String, null: true
    field :step_version, Integer, null: true
    field :error_class, String, null: false
    field :error_message, String, null: false
    field :arguments, GraphQL::Types::JSON, null: false
    field :resolved, Boolean, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
