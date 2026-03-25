require "dry/schema"

class JobOffer < ApplicationRecord
  STEPS_DETAIL_KEYS = %w[discovery fetch analyze enrich score].freeze
  ISO8601_TIMESTAMP_REGEX = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+\-]\d{2}:\d{2})\z/.freeze

  STEP_PAYLOAD_SCHEMA = Dry::Schema.Params do
    config.validate_keys = true

    optional(:at).filled(:string, format?: ISO8601_TIMESTAMP_REGEX)
    optional(:version).filled(:integer, gteq?: 1)
  end

  STEPS_DETAILS_SCHEMA = Dry::Schema.Params do
    config.validate_keys = true

    optional(:discovery).hash(STEP_PAYLOAD_SCHEMA)
    optional(:fetch).hash(STEP_PAYLOAD_SCHEMA)
    optional(:analyze).hash(STEP_PAYLOAD_SCHEMA)
    optional(:enrich).hash(STEP_PAYLOAD_SCHEMA)
    optional(:score).hash(STEP_PAYLOAD_SCHEMA)
  end

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

  has_one_attached :html_file

  enum :remote, REMOTE_VALUES, prefix: true
  enum :employment_type, EMPLOYMENT_TYPES, prefix: true
  enum :offer_language, OFFER_LANGUAGES, prefix: true
  enum :normalized_seniority, SENIORITY_LEVELS, prefix: true
  enum :english_level_required, ENGLISH_LEVELS, prefix: true

  validates :source, :url, :url_hash, :last_seen_at,
            presence: true
  validates :url, :url_hash, uniqueness: true
  validates :hybrid_remote_days_min_per_week,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 5
            },
            allow_nil: true

  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :city, length: { maximum: 255 }, allow_nil: true

  validate :steps_details_must_be_valid

  private

  def steps_details_must_be_valid
    return if steps_details.blank?
    return errors.add(:steps_details, "must be a hash") unless steps_details.is_a?(Hash)

    details = steps_details.deep_stringify_keys
    unknown_steps = details.keys - STEPS_DETAIL_KEYS
    unknown_steps.each { |step| errors.add(:steps_details, "contains unsupported step #{step}") }

    result = STEPS_DETAILS_SCHEMA.call(details.except(*unknown_steps))
    result.errors.each do |error|
      errors.add(:steps_details, normalize_steps_details_error(error.path, error.text))
    end
  end

  def normalize_steps_details_error(path, message)
    step = path[0].to_s
    field = path[1]&.to_s

    if field.nil?
      return "contains unsupported step #{step}" if message == "is not allowed"
      return "step #{step} must be a hash" if message == "must be a hash"

      return "step #{step} #{message}"
    end

    return "step #{step} contains unsupported keys #{field}" if message == "is not allowed"
    return "step #{step} has an invalid version" if field == "version"
    return "step #{step} has an invalid at timestamp" if field == "at"

    "step #{step} #{field} #{message}"
  end
end
