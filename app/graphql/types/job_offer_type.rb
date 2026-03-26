# frozen_string_literal: true

module Types
  class JobOfferType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: true
    field :company, String, null: true
    field :city, String, null: true
    field :url, String, null: false
    field :source, String, null: false
    field :location_mode, Types::LocationModeEnum, null: true
    field :employment_type, String, null: true
    field :normalized_seniority, String, null: true
    field :offer_language, String, null: true
    field :english_level_required, String, null: true
    field :hybrid_remote_days_min_per_week, Integer, null: true
    field :score, Integer, null: true
    field :score_breakdown, GraphQL::Types::JSON, null: true
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

    def first_seen_at
      at = object.steps_details&.dig("discovery", "at")
      DateTime.parse(at) if at
    end
  end
end
