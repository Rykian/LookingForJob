# frozen_string_literal: true

module Types
  class DashboardMetricsType < Types::BaseObject
    description "Top-level sourcing pipeline counters."

    field :total, Integer, null: false, description: "Total offers in database."
    field :fetched, Integer, null: false, description: "Offers with fetched HTML content."
    field :enriched, Integer, null: false, description: "Offers enriched by LLM step."
    field :scored, Integer, null: false, description: "Offers scored against profile."
    field :average_score, Float, null: true, description: "Average score across scored offers."
    field :top_sources, [Types::SourceCountType], null: false,
      description: "Top sources ordered by offer count."
  end
end
