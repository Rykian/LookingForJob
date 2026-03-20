class JobOffer < ApplicationRecord
  REMOTE_VALUES = {
    yes: "yes",
    hybrid: "hybrid",
    no: "no"
  }.freeze

  EMPLOYMENT_TYPES = {
    permanent: "PERMANENT",
    fixed_term: "FIXED_TERM",
    contract: "CONTRACT",
    freelance: "FREELANCE",
    internship: "INTERNSHIP",
    apprenticeship: "APPRENTICESHIP",
    temporary: "TEMPORARY",
    full_time: "FULL_TIME",
    part_time: "PART_TIME"
  }.freeze

  OFFER_LANGUAGES = {
    fr: "fr",
    en: "en",
    other: "other"
  }.freeze

  SENIORITY_LEVELS = {
    intern: "intern",
    junior: "junior",
    mid: "mid",
    senior: "senior",
    staff: "staff"
  }.freeze

  ENGLISH_LEVELS = {
    none: "none",
    basic: "basic",
    professional: "professional",
    fluent: "fluent"
  }.freeze

  enum :remote, REMOTE_VALUES, prefix: true
  enum :employment_type, EMPLOYMENT_TYPES, prefix: true
  enum :offer_language, OFFER_LANGUAGES, prefix: true
  enum :normalized_seniority, SENIORITY_LEVELS, prefix: true
  enum :english_level_required, ENGLISH_LEVELS, prefix: true

  validates :source, :url, :url_hash, :first_seen_at, :last_seen_at,
            presence: true
  validates :url, :url_hash, uniqueness: true
  validates :hybrid_remote_days_min_per_week,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 5
            },
            allow_nil: true
end
