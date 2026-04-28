# frozen_string_literal: true

class Types::SubscriptionType < GraphQL::Schema::Object
    field :sourcing_status, subscription: Subscriptions::SourcingStatus,
      description: "Live sourcing queue and worker activity status."
end
