# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    include Types::Queries::DashboardMetrics
    include Types::Queries::JobOffer
    include Types::Queries::JobOffers
    include Types::Queries::Providers
    include Types::Queries::Runs
    include Types::Queries::ScoringProfile
    include Types::Queries::Technologies

    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [Types::NodeType, null: true], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ID], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end
  end
end
