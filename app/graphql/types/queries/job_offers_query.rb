# frozen_string_literal: true

module Types
  module Queries
    module JobOffersQuery
      extend ActiveSupport::Concern

      included do
        field :job_offers, Types::JobOffersResultType, null: false,
          description: "List job offers with optional filters and pagination." do
          argument :page, Integer, required: false, default_value: 1,
            description: "1-based page number."
          argument :per_page, Integer, required: false, default_value: 25,
            description: "Items per page."
          argument :source, String, required: false,
            description: "Filter by offer source (for example: linkedin)."
          argument :location_modes, [Types::LocationModeEnum], required: false,
            description: "Filter by one or more location modes."
          argument :first_seen_after, GraphQL::Types::ISO8601DateTime, required: false,
            description: "Filter by first seen timestamp lower bound (inclusive)."
          argument :first_seen_before, GraphQL::Types::ISO8601DateTime, required: false,
            description: "Filter by first seen timestamp upper bound (inclusive)."
          argument :last_seen_after, GraphQL::Types::ISO8601DateTime, required: false,
            description: "Filter by last seen timestamp lower bound (inclusive)."
          argument :last_seen_before, GraphQL::Types::ISO8601DateTime, required: false,
            description: "Filter by last seen timestamp upper bound (inclusive)."
          argument :sort_by, String, required: false, default_value: "first_seen_at",
            description: "Sort field: first_seen_at, last_seen_at, score, company, title."
          argument :sort_direction, String, required: false, default_value: "desc",
            description: "Sort direction: asc or desc."
          argument :technologies, [String], required: false,
            description: "Filter offers by matching any of these technologies (primary or secondary)."
        end

        field :job_offer, Types::JobOfferType, null: true,
          description: "Find a single job offer by ID." do
          argument :id, GraphQL::Types::ID, required: true, description: "Job offer ID."
        end
      end

      def job_offers(page:, per_page:, source: nil, location_modes: nil, first_seen_after: nil, first_seen_before: nil, last_seen_after: nil, last_seen_before: nil, sort_by: "first_seen_at", sort_direction: "desc", technologies: nil)
        scope = JobOffer.where(rejected: false)
        scope = scope.where(source: source) if source.present?
        scope = scope.where(location_mode: location_modes) if location_modes.present?

        if first_seen_after.present?
          scope = scope.where("(steps_details->'discovery'->>'at')::timestamptz >= ?", first_seen_after)
        end

        if first_seen_before.present?
          scope = scope.where("(steps_details->'discovery'->>'at')::timestamptz <= ?", first_seen_before)
        end

        scope = scope.where("last_seen_at >= ?", last_seen_after) if last_seen_after.present?
        scope = scope.where("last_seen_at <= ?", last_seen_before) if last_seen_before.present?

        if technologies.present?
          norm_techs = technologies.map { |t| t.downcase.gsub(/[^a-z]/, "") }
          sql = <<~SQL.squish
            (
              ARRAY(
                SELECT lower(regexp_replace(t, '[^a-z]', '', 'g')) FROM unnest(primary_technologies) AS t
              ) && ARRAY[?]::text[]
            )
            OR
            (
              ARRAY(
                SELECT lower(regexp_replace(t, '[^a-z]', '', 'g')) FROM unnest(secondary_technologies) AS t
              ) && ARRAY[?]::text[]
            )
          SQL
          scope = scope.where(sql, norm_techs, norm_techs)
        end

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

      def job_offer(id:)
        JobOffer.where(rejected: false).find_by(id: id)
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
end
