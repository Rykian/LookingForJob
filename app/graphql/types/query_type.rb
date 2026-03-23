# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
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

    # --- Job Offers ---

    field :job_offers, Types::JobOffersResultType, null: false do
      argument :page, Integer, required: false, default_value: 1
      argument :per_page, Integer, required: false, default_value: 25
      argument :source, String, required: false
      argument :remote, String, required: false
      argument :scored, Boolean, required: false
    end

    def job_offers(page:, per_page:, source: nil, remote: nil, scored: nil)
      scope = JobOffer.all
      scope = scope.where(source: source) if source.present?
      scope = scope.where(remote: remote) if remote.present?
      scope = scope.where.not(scored_at: nil) if scored == true
      scope = scope.where(scored_at: nil) if scored == false

      total_count = scope.count
      total_pages = (total_count.to_f / per_page).ceil
      nodes = scope.order(first_seen_at: :desc).offset((page - 1) * per_page).limit(per_page)

      OpenStruct.new(nodes: nodes, total_count: total_count, total_pages: total_pages)
    end

    field :job_offer, Types::JobOfferType, null: true do
      argument :id, ID, required: true
    end

    def job_offer(id:)
      JobOffer.find_by(id: id)
    end

    # --- Dashboard ---

    field :dashboard_metrics, Types::DashboardMetricsType, null: false

    def dashboard_metrics
      total     = JobOffer.count
      fetched   = JobOffer.where.not(fetched_at: nil).count
      enriched  = JobOffer.where.not(enriched_at: nil).count
      scored    = JobOffer.where.not(scored_at: nil).count
      avg_score = JobOffer.where.not(score: nil).average(:score)&.to_f&.round(1)

      top_sources = JobOffer
        .group(:source)
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(5)
        .count
        .map { |src, cnt| OpenStruct.new(source: src, count: cnt) }

      OpenStruct.new(
        total: total,
        fetched: fetched,
        enriched: enriched,
        scored: scored,
        average_score: avg_score,
        top_sources: top_sources
      )
    end

    # --- Scoring Profile ---

    field :scoring_profile, GraphQL::Types::JSON, null: false

    def scoring_profile
      Sourcing::ScoringProfile.load
    end
  end
end
