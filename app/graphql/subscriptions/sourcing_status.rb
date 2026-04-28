# frozen_string_literal: true

module Subscriptions
  class SourcingStatus < Subscriptions::BaseSubscription
    description "Live sourcing queue/worker state for UI auto-refresh."

    field :active, Boolean, null: false
    field :queued_count, Integer, null: false
    field :running_count, Integer, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    def subscribe
      Sourcing::JobStatusService.call
    end

    def update
      object
    end
  end
end
