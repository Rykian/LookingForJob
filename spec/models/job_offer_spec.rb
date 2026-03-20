require "rails_helper"

RSpec.describe JobOffer, type: :model do
  describe "enum declarations" do
    it do
      is_expected.to define_enum_for(:remote)
        .with_values(described_class::REMOTE_VALUES)
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
      described_class.new(
        source: "linkedin",
        url: "https://example.com/jobs/1",
        url_hash: "hash-1",
        first_seen_at: Time.current,
        last_seen_at: Time.current
      )
    end

    it { is_expected.to validate_presence_of(:source) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:url_hash) }
    it { is_expected.to validate_presence_of(:first_seen_at) }
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
end
