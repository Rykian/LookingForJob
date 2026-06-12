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
          argument :language, String, required: false,
            description: "ISO 639-1 code; paired with max_language_level."
          argument :max_language_level, Types::LanguageLevelEnum, required: false,
            description: "Maximum level you can handle; offers requiring more are excluded."
          argument :min_commute_minutes, Integer, required: false,
            description: "Only return offers with a commute duration >= this value (uses profile origin and mode)."
          argument :max_commute_minutes, Integer, required: false,
            description: "Only return offers with a commute duration <= this value (uses profile origin and mode)."
          argument :run_id, GraphQL::Types::ID, required: false,
            description: "Filter offers to those discovered in a specific run."
          argument :new_only, GraphQL::Types::Boolean, required: false, default_value: false,
            description: "When true and run_id is set, only return offers that appear exclusively in that run (never seen in any other run)."
          argument :exclude_duplicates, GraphQL::Types::Boolean, required: false, default_value: true,
            description: "When true (default), exclude duplicate offers and only show canonical ones."
          argument :search, String, required: false,
            description: "Fuzzy full-text search across title, company, city, technologies and description_html."
          argument :company_id, GraphQL::Types::ID, required: false,
            description: "Filter offers linked to a company, as poster or as final client."
        end

        field :job_offer_language_codes, [String], null: false,
          description: "ISO 639-1 codes present in job offer language requirements (cache-backed)."
      end

      def job_offer_language_codes
        ::JobOffer.known_language_codes
      end

      def job_offers(page:, per_page:, source: nil, location_modes: nil, first_seen_after: nil, first_seen_before: nil, last_seen_after: nil, last_seen_before: nil, sort_by: "first_seen_at", sort_direction: "desc", technologies: nil, language: nil, max_language_level: nil, min_commute_minutes: nil, max_commute_minutes: nil, run_id: nil, new_only: false, exclude_duplicates: true, search: nil, company_id: nil)
        scope = ::JobOffer.where(rejected: false, disabled: false)
        scope = scope.canonical if exclude_duplicates
        scope = scope.where("company_id = :id OR final_company_id = :id", id: company_id) if company_id.present?

        if search.present?
          raw = MeiliSearch::Rails.client.index("JobOffer").search(search, { limit: 10_000, attributesToRetrieve: ["id"] })
          ids = raw["hits"].map { |h| h["id"].to_i }
          scope = scope.where(id: ids)
        end

        if run_id.present?
          scope = scope.joins(:run_job_offers).where(run_job_offers: { run_id: run_id })
          if new_only
            scope = scope.where(
              "NOT EXISTS (SELECT 1 FROM run_job_offers rjo WHERE rjo.job_offer_id = job_offers.id AND rjo.run_id != ?)",
              run_id
            )
          end
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

        if language.present? && max_language_level.present?
          allowed = ::JobOffer::LANGUAGE_LEVELS.take(::JobOffer::LANGUAGE_LEVELS.index(max_language_level) + 1)
          clauses = ["NOT (languages @> ?)"] + allowed.map { "languages @> ?" }
          binds = [[{ language: language }].to_json] +
                  allowed.map { |level| [{ language: language, level: level }].to_json }
          scope = scope.where(clauses.join(" OR "), *binds)
        end

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
          .includes(:company, :final_company)
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
          "company" => "company_name",
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
