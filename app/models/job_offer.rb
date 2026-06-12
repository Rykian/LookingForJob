require "dry/schema"

class JobOffer < ApplicationRecord
  include MeiliSearch::Rails

  meilisearch enqueue: true do
    searchable_attributes [:title, :company_name, :city, :keywords, :primary_technologies, :secondary_technologies, :description_html]
  end

  STEPS_DETAIL_KEYS = %w[discovery fetch analyze enrich commute score company].freeze
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
    optional(:commute).hash(STEP_PAYLOAD_SCHEMA)
    optional(:score).hash(STEP_PAYLOAD_SCHEMA)
    optional(:company).hash(STEP_PAYLOAD_SCHEMA)
  end

  LOCATION_MODE_VALUES = {
    remote: "remote",
    hybrid: "hybrid",
    on_site: "on-site",
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
    part_time: "PART_TIME",
  }.freeze

  OFFER_LANGUAGES = {
    fr: "fr",
    en: "en",
    other: "other",
  }.freeze

  SENIORITY_LEVELS = {
    intern: "intern",
    junior: "junior",
    mid: "mid",
    senior: "senior",
    staff: "staff",
  }.freeze

  # Order is load-bearing: the language filter treats earlier levels as lower.
  LANGUAGE_LEVELS = %w[not_required basic professional fluent].freeze

  LANGUAGE_CODES_CACHE_KEY = "job_offers:language_codes"

  has_one_attached :html_file

  belongs_to :commute_city, class_name: "Commute::City", optional: true, inverse_of: :job_offers
  belongs_to :canonical_offer, class_name: "JobOffer", foreign_key: :canonical_id, optional: true, inverse_of: :duplicate_offers
  belongs_to :company, optional: true, inverse_of: :job_offers
  belongs_to :final_company, class_name: "Company", optional: true, inverse_of: :final_client_offers

  has_many :run_job_offers, dependent: :delete_all
  has_many :runs, through: :run_job_offers
  has_many :pipeline_errors, dependent: :delete_all
  has_many :duplicate_offers, class_name: "JobOffer", foreign_key: :canonical_id, dependent: :nullify, inverse_of: :canonical_offer

  scope :canonical, -> { where(canonical_id: nil) }
  scope :duplicates, -> { where.not(canonical_id: nil) }

  def duplicate? = canonical_id.present?
  def canonical? = canonical_id.nil?

  enum :location_mode, LOCATION_MODE_VALUES, prefix: true
  enum :employment_type, EMPLOYMENT_TYPES, prefix: true
  enum :offer_language, OFFER_LANGUAGES, prefix: true
  enum :normalized_seniority, SENIORITY_LEVELS, prefix: true

  validates :source, :url, :url_hash, :last_seen_at,
            presence: true
  validates :url, :url_hash, uniqueness: true
  validates :hybrid_remote_days_min_per_week,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1,
              less_than_or_equal_to: 5,
            },
            allow_nil: true

  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :city, length: { maximum: 255 }, allow_nil: true

  validate :steps_details_must_be_valid
  validate :languages_must_be_valid
  validate :final_client_guesses_must_be_valid

  after_commit :register_language_codes, if: :saved_change_to_languages?

  def self.valid_language_code?(code)
    code.is_a?(String) && ISO_639.find_by_code(code)&.alpha2 == code
  end

  def self.known_language_codes
    Rails.cache.fetch(LANGUAGE_CODES_CACHE_KEY, expires_in: 1.year) do
      connection.select_values(<<~SQL.squish).sort
        SELECT DISTINCT jsonb_array_elements(languages)->>'language' FROM job_offers
      SQL
    end
  end

  private

  def register_language_codes
    codes = languages.map { |l| l["language"] }
    known = self.class.known_language_codes
    missing = codes - known
    return if missing.empty?

    Rails.cache.write(LANGUAGE_CODES_CACHE_KEY, (known + missing).sort, expires_in: 1.year)
  end

  def languages_must_be_valid
    return if languages == []
    return errors.add(:languages, "must be an array") unless languages.is_a?(Array)

    seen = []
    languages.each do |entry|
      unless entry.is_a?(Hash) && entry.keys.sort == %w[language level]
        errors.add(:languages, "entries must be hashes with language and level keys")
        next
      end

      language = entry["language"]
      level = entry["level"]
      errors.add(:languages, "has invalid language code #{language}") unless self.class.valid_language_code?(language)
      errors.add(:languages, "has invalid level #{level}") unless LANGUAGE_LEVELS.include?(level)
      errors.add(:languages, "contains duplicate language #{language}") if seen.include?(language)
      seen << language
    end
  end

  def final_client_guesses_must_be_valid
    return if final_client_guesses == []
    return errors.add(:final_client_guesses, "must be an array") unless final_client_guesses.is_a?(Array)

    final_client_guesses.each do |entry|
      unless entry.is_a?(Hash) && entry.keys.sort == %w[confidence name reasons]
        errors.add(:final_client_guesses, "entries must be hashes with name, confidence and reasons keys")
        next
      end

      errors.add(:final_client_guesses, "has invalid name") unless entry["name"].is_a?(String) && entry["name"].present?
      errors.add(:final_client_guesses, "has invalid reasons") unless entry["reasons"].is_a?(String)
      confidence = entry["confidence"]
      errors.add(:final_client_guesses, "has invalid confidence") unless confidence.is_a?(Numeric) && confidence.between?(0, 1)
    end
  end

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
