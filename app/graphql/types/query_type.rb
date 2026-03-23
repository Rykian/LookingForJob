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

    field :job_offers, Types::JobOffersResultType, null: false,
      description: "List job offers with optional filters and pagination." do
      argument :page, Integer, required: false, default_value: 1,
        description: "1-based page number."
      argument :per_page, Integer, required: false, default_value: 25,
        description: "Items per page."
      argument :source, String, required: false,
        description: "Filter by offer source (for example: linkedin)."
      argument :remote, String, required: false,
        description: "Filter by remote mode (yes, hybrid, no)."
      argument :scored, Boolean, required: false,
        description: "When true returns only scored offers; when false only unscored offers."
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

      {
        nodes: nodes,
        total_count: total_count,
        total_pages: total_pages,
      }
    end

    field :job_offer, Types::JobOfferType, null: true,
      description: "Find a single job offer by ID." do
      argument :id, ID, required: true, description: "Job offer ID."
    end

    def job_offer(id:)
      JobOffer.find_by(id: id)
    end

    # --- Dashboard ---

    field :dashboard_metrics, Types::DashboardMetricsType, null: false,
      description: "Aggregated pipeline metrics used by the dashboard."

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
        .map { |src, cnt| { source: src, count: cnt } }

      {
        total: total,
        fetched: fetched,
        enriched: enriched,
        scored: scored,
        average_score: avg_score,
        top_sources: top_sources
      }
    end

    # --- Scoring Profile ---

    field :scoring_profile, GraphQL::Types::JSON, null: false,
      description: "Current file-backed scoring profile JSON."

    def scoring_profile
      Sourcing::ScoringProfile.load
    end
  end
end
