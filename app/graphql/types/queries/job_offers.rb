# frozen_string_literal: true

module Types
  module Queries
    module JobOffers
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
          argument :english_levels_required, [String], required: false,
            description: "Filter by required English level (none, basic, professional, fluent)."
          argument :min_commute_minutes, Integer, required: false,
            description: "Only return offers with a commute duration >= this value (uses profile origin and mode)."
          argument :max_commute_minutes, Integer, required: false,
            description: "Only return offers with a commute duration <= this value (uses profile origin and mode)."
          argument :run_id, GraphQL::Types::ID, required: false,
            description: "Filter offers to those discovered in a specific run."
        end
      end

      def job_offers(page:, per_page:, source: nil, location_modes: nil, first_seen_after: nil, first_seen_before: nil, last_seen_after: nil, last_seen_before: nil, sort_by: "first_seen_at", sort_direction: "desc", technologies: nil, english_levels_required: nil, min_commute_minutes: nil, max_commute_minutes: nil, run_id: nil)
        scope = ::JobOffer.where(rejected: false, disabled: false)

        if run_id.present?
          scope = scope.joins(:run_job_offers).where(run_job_offers: { run_id: run_id })
        end
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

        scope = scope.where(english_level_required: english_levels_required) if english_levels_required.present?

        if min_commute_minutes.present? || max_commute_minutes.present?
          cfg = context[:scoring_profile]&.dig(:location, :commute)
          if cfg
            origin_id = Commute::City.find_by(normalized_name: Commute::City.normalize(cfg[:origin_city]))&.id
            if origin_id
              duration_range = if min_commute_minutes && max_commute_minutes
                min_commute_minutes..max_commute_minutes
              elsif min_commute_minutes
                min_commute_minutes..
              else
                ..max_commute_minutes
              end
              scope = scope
                .joins("INNER JOIN commute_durations ON commute_durations.destination_city_id = job_offers.commute_city_id")
                .where(commute_durations: { origin_city_id: origin_id, mode: cfg[:mode], duration_minutes: duration_range })
            end
          end
        end

        if technologies.present?
          t = ::JobOffer.arel_table
          # Works only after a first dedup job pass that ensures
          # primary_technologies and secondary_technologies are caninocalized.
          scope = scope.where(
            t[:primary_technologies].overlaps(technologies)
              .or(t[:secondary_technologies].overlaps(technologies))
          )
        end

        sort_column = normalize_sort_column(sort_by)
        direction = normalize_sort_direction(sort_direction)

        total_count = scope.count
        total_pages = (total_count.to_f / per_page).ceil
        nodes = scope
          # Secondary sort by id to ensure deterministic order when primary sort values are equal.
          .order(Arel.sql("#{sort_column} #{direction} NULLS LAST, id DESC"))
          .offset((page - 1) * per_page)
          .limit(per_page)

        {
          nodes: nodes,
          total_count: total_count,
          total_pages: total_pages,
        }
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
