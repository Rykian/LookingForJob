class Company < ApplicationRecord
  include MeiliSearch::Rails

  meilisearch enqueue: true do
    searchable_attributes [:name, :alias_names]
  end

  # Stripped from the end of names during normalization so "Acme SAS" and
  # "Acme" resolve to the same company. Order: longest first to avoid partial
  # strips ("sasu" before "sas" before "sa").
  LEGAL_SUFFIXES = %w[sasu sarl sas sa gmbh ltd inc group groupe].freeze
  LEGAL_SUFFIXES_REGEX = /\s+(?:#{LEGAL_SUFFIXES.join("|")})\z/.freeze

  has_many :aliases, class_name: "CompanyAlias", dependent: :destroy, inverse_of: :company
  has_many :job_offers, dependent: :nullify
  has_many :final_client_offers,
           class_name: "JobOffer",
           foreign_key: :final_company_id,
           dependent: :nullify,
           inverse_of: :final_company

  validates :name, presence: true

  def self.normalize(raw)
    normalized = Sourcing::DeduplicateOffersService.normalize_text(raw)
    loop do
      stripped = normalized.sub(LEGAL_SUFFIXES_REGEX, "")
      break if stripped == normalized

      normalized = stripped
    end
    normalized
  end

  # Resolves a raw company name through aliases, creating the company and its
  # own-name alias when unknown. Uniqueness lives on company_aliases
  # (normalized_name unique index); create_or_find_by! keeps this race-safe
  # under concurrent CompanyJobs (see Commute::City for the rationale).
  def self.find_or_create_by_name!(raw)
    normalized = normalize(raw)
    return nil if normalized.blank?

    existing = CompanyAlias.find_by(normalized_name: normalized)
    return existing.company if existing

    transaction(requires_new: true) do
      company = create!(name: raw.to_s.strip)
      company.aliases.create!(name: raw.to_s.strip, normalized_name: normalized)
      company
    end
  rescue ActiveRecord::RecordNotUnique
    CompanyAlias.find_by!(normalized_name: normalized).company
  end

  def alias_names
    aliases.pluck(:name)
  end

  # Technologies seen on offers where this company is the final client: offers
  # it posted directly plus offers recruiters posted on its behalf.
  # Recruiter-posted offers are excluded — their stack belongs to the client.
  def top_technologies(limit: 10)
    sql = <<~SQL.squish
      SELECT tech
      FROM job_offers, unnest(primary_technologies || secondary_technologies) AS tech
      WHERE final_company_id = :id
         OR (company_id = :id AND posted_by_recruiter IS NOT TRUE)
      GROUP BY tech
      ORDER BY COUNT(*) DESC, tech ASC
      LIMIT :limit
    SQL
    self.class.connection.select_values(
      self.class.sanitize_sql_array([sql, { id: id, limit: limit }])
    )
  end
end
