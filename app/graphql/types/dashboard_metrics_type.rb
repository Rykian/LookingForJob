# frozen_string_literal: true

module Types
  class DashboardMetricsType < Types::BaseObject
    field :total, Integer, null: false
    field :fetched, Integer, null: false
    field :enriched, Integer, null: false
    field :scored, Integer, null: false
    field :average_score, Float, null: true
    field :top_sources, [Types::SourceCountType], null: false
  end
end
