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
      argument :location_mode, Types::LocationModeEnum, required: false,
        description: "Filter by location mode."
      argument :scored, Boolean, required: false,
        description: "When true returns only scored offers; when false only unscored offers."
      argument :sort_by, String, required: false, default_value: "first_seen_at",
        description: "Sort field: first_seen_at, last_seen_at, score, company, title."
      argument :sort_direction, String, required: false, default_value: "desc",
        description: "Sort direction: asc or desc."
    end

    def job_offers(page:, per_page:, source: nil, location_mode: nil, scored: nil, sort_by: "first_seen_at", sort_direction: "desc")
      scope = JobOffer.all
      scope = scope.where(source: source) if source.present?
      scope = scope.where(location_mode: location_mode) if location_mode.present?
      scope = scope.where("steps_details ? 'score'") if scored == true
      scope = scope.where("NOT (steps_details ? 'score')") if scored == false

      sort_column = normalize_sort_column(sort_by)
      direction = normalize_sort_direction(sort_direction)

      total_count = scope.count
      total_pages = (total_count.to_f / per_page).ceil
      nodes = scope
        .order(Arel.sql("#{sort_column} #{direction} NULLS LAST"))
        .offset((page - 1) * per_page)
        .limit(per_page)

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
      total    = JobOffer.count
      fetched  = JobOffer.where("steps_details ? 'fetch'").count
      enriched = JobOffer.where("steps_details ? 'enrich'").count
      scored   = JobOffer.where("steps_details ? 'score'").count
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

    # --- Scoring Profile ---

    field :scoring_profile, GraphQL::Types::JSON, null: false,
      description: "Current file-backed scoring profile JSON."

    def scoring_profile
      Sourcing::ScoringProfile.load
    end

    private

    def normalize_sort_column(sort_by)
      allowed = {
        "first_seen_at" => "(steps_details->'discovery'->>'at')::timestamptz",
        "last_seen_at" => "last_seen_at",
        "score" => "score",
        "company" => "company",
        "title" => "title",
      }
      allowed.fetch(sort_by.to_s, "(steps_details->'discovery'->>'at')::timestamptz")
    end

    def normalize_sort_direction(sort_direction)
      return "asc" if sort_direction.to_s.downcase == "asc"

      "desc"
    end
  end
end
