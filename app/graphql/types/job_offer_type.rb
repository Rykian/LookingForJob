# frozen_string_literal: true

module Types
  class JobOfferType < Types::BaseObject
    # Batches Commute::Duration lookups by destination city for a fixed
    # (origin_city_id, mode) pair. Each unique destination is resolved with a
    # single SQL query per (origin, mode) group, regardless of how many offers
    # reference it in the same GraphQL query.
    class CommuteDuration < GraphQL::Dataloader::Source
      def initialize(origin_city_id:, mode:)
        @origin_city_id = origin_city_id
        @mode = mode
      end

      def fetch(destination_city_ids)
        durations = ::Commute::Duration
          .where(origin_city_id: @origin_city_id, mode: @mode, destination_city_id: destination_city_ids)
          .pluck(:destination_city_id, :duration_minutes)
          .to_h
        destination_city_ids.map { |id| durations[id] }
      end
    end

    class FinalClientGuessType < Types::BaseObject
      description "An LLM guess of the final client behind a recruiter-posted offer."

      field :name, String, null: false
      field :confidence, Float, null: false
      field :reasons, String, null: false,
        description: "Short justification for this guess."

      def name = object["name"]
      def confidence = object["confidence"]
      def reasons = object["reasons"].to_s
    end

    field :id, ID, null: false
    field :title, String, null: true
    field :company_name, String, null: true,
      description: "Raw company name as seen on the offer."
    field :company, Types::CompanyType, null: true,
      description: "Company that posted the offer."
    field :final_company, Types::CompanyType, null: true,
      description: "Final client behind the offer (linked guess or manual pick)."
    field :posted_by_recruiter, Boolean, null: true,
      description: "True when posted by a recruiting intermediary; null when unclassified."
    field :final_client_guesses, [FinalClientGuessType], null: false,
      description: "LLM guesses of the final client, sorted by confidence."
    field :city, String, null: true
    field :url, String, null: false
    field :source, String, null: false
    field :location_mode, Types::LocationModeEnum, null: true
    field :employment_type, String, null: true
    field :normalized_seniority, String, null: true
    field :offer_language, String, null: true
    field :languages, [Types::LanguageRequirementType], null: false
    field :hybrid_remote_days_min_per_week, Integer, null: true
    field :score, Integer, null: true
    field :score_breakdown, GraphQL::Types::JSON, null: true
    field :commute_duration_minutes, Integer, null: true,
      description: "One-way travel time from the configured commute origin to this offer's city, in minutes. Null when no commute profile is set, the offer is remote, or the duration hasn't been computed yet."
    field :commute_within_max, Boolean, null: true,
      description: "True when commute_duration_minutes is within the profile's max_minutes. Null when no commute profile is set or the duration is unknown."
    field :description_html, String, null: true
    field :primary_technologies, [String], null: true
    field :secondary_technologies, [String], null: true
    field :salary_min_minor, Integer, null: true
    field :salary_max_minor, Integer, null: true
    field :salary_currency, String, null: true
    field :posted_at, GraphQL::Types::ISO8601DateTime, null: true
    field :first_seen_at, GraphQL::Types::ISO8601DateTime, null: true
    field :last_seen_at, GraphQL::Types::ISO8601DateTime, null: false
    field :steps_details, Types::StepsDetailsType, null: true
    field :canonical_id, ID, null: true,
      description: "ID of the canonical offer when this offer is a duplicate."
    field :is_duplicate, Boolean, null: false,
      description: "True when this offer has been identified as a duplicate of another."
    field :duplicate_count, Integer, null: false,
      description: "Number of duplicate offers pointing to this canonical offer."

    def is_duplicate
      object.duplicate?
    end

    def duplicate_count
      object.duplicate_offers.size
    end

    def first_seen_at
      at = object.steps_details&.dig("discovery", "at")
      DateTime.parse(at) if at
    end

    def commute_duration_minutes
      return nil if object.commute_city_id.nil?

      cfg = commute_cfg
      return nil if cfg.nil?

      origin_id = commute_origin_id
      return nil if origin_id.nil?

      dataloader
        .with(CommuteDuration, origin_city_id: origin_id, mode: cfg[:mode])
        .load(object.commute_city_id)
    end

    def commute_within_max
      minutes = commute_duration_minutes
      max = commute_cfg&.dig(:max_minutes)
      return nil if minutes.nil? || max.nil?

      minutes <= max
    end

    private

    def commute_cfg
      context[:scoring_profile]&.dig(:location, :commute)
    end

    def commute_origin_id
      return context[:commute_origin_id] if context.key?(:commute_origin_id)

      cfg = commute_cfg
      context[:commute_origin_id] = cfg && Commute::City.find_by(normalized_name: Commute::City.normalize(cfg[:origin_city]))&.id
    end
  end
end
