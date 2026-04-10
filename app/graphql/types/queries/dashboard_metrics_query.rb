# frozen_string_literal: true

module Types
  module Queries
    module DashboardMetricsQuery
      extend ActiveSupport::Concern

      included do
        field :dashboard_metrics, Types::DashboardMetricsType, null: false,
          description: "Aggregated pipeline metrics used by the dashboard."
      end

      def dashboard_metrics
        total = JobOffer.count
        fetched = JobOffer.where("steps_details ? 'fetch'").count
        enriched = JobOffer.where("steps_details ? 'enrich'").count
        scored = JobOffer.where("steps_details ? 'score'").count
        avg_score = JobOffer.where.not(score: nil).average(:score)&.to_f&.round(1)

        top_sources = JobOffer
          .group(:source)
          .order(Arel.sql("COUNT(*) DESC"))
          .limit(5)
          .count
          .map { |src, cnt| { source: src, count: cnt } }

        {
          total: total,
          fetched: fetched,
          enriched: enriched,
          scored: scored,
          average_score: avg_score,
          top_sources: top_sources,
        }
      end
    end
  end
end
