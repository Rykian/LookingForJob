# frozen_string_literal: true

module Types
  class StepDetailType < Types::BaseObject
    description "Timestamp and version for a single pipeline step."

    field :at, String, null: true, hash_key: "at", description: "ISO8601 timestamp when the step completed."
    field :version, Integer, null: true, hash_key: "version", description: "Step schema version."
  end
end
