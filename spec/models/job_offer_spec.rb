require "rails_helper"

RSpec.describe JobOffer, type: :model do
  def build_job_offer(**attrs)
    described_class.new(
      {
        source: "linkedin",
        url: "https://example.com/jobs/1",
        url_hash: "hash-1",
        last_seen_at: Time.current,
      }.merge(attrs)
    )
  end

  describe "enum declarations" do
    it do
      is_expected.to define_enum_for(:location_mode)
        .with_values(described_class::LOCATION_MODE_VALUES)
        .without_instance_methods
        .without_scopes
        .backed_by_column_of_type(:string)
    end

    it do
      is_expected.to define_enum_for(:employment_type)
        .with_values(described_class::EMPLOYMENT_TYPES)
        .without_instance_methods
        .without_scopes
        .backed_by_column_of_type(:string)
    end

    it do
      is_expected.to define_enum_for(:offer_language)
        .with_values(described_class::OFFER_LANGUAGES)
        .without_instance_methods
        .without_scopes
        .backed_by_column_of_type(:string)
    end

    it do
      is_expected.to define_enum_for(:normalized_seniority)
        .with_values(described_class::SENIORITY_LEVELS)
        .without_instance_methods
        .without_scopes
        .backed_by_column_of_type(:string)
    end

    it do
      is_expected.to define_enum_for(:english_level_required)
        .with_values(described_class::ENGLISH_LEVELS)
        .without_instance_methods
        .without_scopes
        .backed_by_column_of_type(:string)
    end
  end

  describe "validators" do
    subject(:job_offer) do
      build_job_offer
    end

    it { is_expected.to validate_presence_of(:source) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:url_hash) }
    it { is_expected.to validate_presence_of(:last_seen_at) }

    it { is_expected.to validate_uniqueness_of(:url) }
    it { is_expected.to validate_uniqueness_of(:url_hash) }

    it do
      expect(job_offer).to allow_value(nil).for(:hybrid_remote_days_min_per_week)
    end

    it do
      expect(job_offer).to validate_numericality_of(:hybrid_remote_days_min_per_week)
        .only_integer
        .is_greater_than_or_equal_to(1)
        .is_less_than_or_equal_to(5)
    end
  end

  describe "steps_details validation" do
    it "accepts supported steps and payload shape" do
      job_offer = build_job_offer(
        steps_details: {
          discovery: { at: Time.current.iso8601, version: 1 },
          fetch: { at: Time.current.iso8601, version: 2 },
        }
      )

      expect(job_offer).to be_valid
    end

    it "rejects unsupported top-level keys" do
      job_offer = build_job_offer(steps_details: { publish: { at: Time.current.iso8601, version: 1 } })

      expect(job_offer).not_to be_valid
      expect(job_offer.errors[:steps_details]).to include("contains unsupported step publish")
    end

    it "rejects non-hash step payloads" do
      job_offer = build_job_offer(steps_details: { discovery: "invalid" })

      expect(job_offer).not_to be_valid
      expect(job_offer.errors[:steps_details]).to include("step discovery must be a hash")
    end

    it "rejects unsupported nested payload keys" do
      job_offer = build_job_offer(
        steps_details: {
          discovery: { at: Time.current.iso8601, version: 1, source: "manual" },
        }
      )

      expect(job_offer).not_to be_valid
      expect(job_offer.errors[:steps_details]).to include("step discovery contains unsupported keys source")
    end

    it "rejects invalid at timestamp" do
      job_offer = build_job_offer(steps_details: { discovery: { at: "not-iso8601", version: 1 } })

      expect(job_offer).not_to be_valid
      expect(job_offer.errors[:steps_details]).to include("step discovery has an invalid at timestamp")
    end

    it "rejects invalid version value" do
      job_offer = build_job_offer(steps_details: { discovery: { at: Time.current.iso8601, version: 0 } })

      expect(job_offer).not_to be_valid
      expect(job_offer.errors[:steps_details]).to include("step discovery has an invalid version")
    end
  end
end
