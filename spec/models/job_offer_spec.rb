require "rails_helper"

RSpec.describe JobOffer, type: :model do
  describe "constants" do
    it "defines remote values" do
      expect(described_class::REMOTE_VALUES.values).to match_array(%w[yes hybrid no])
    end

    it "defines employment types" do
      expect(described_class::EMPLOYMENT_TYPES.values).to include("PERMANENT", "FULL_TIME")
    end

    it "defines language/seniority/english levels" do
      expect(described_class::OFFER_LANGUAGES.values).to match_array(%w[fr en other])
      expect(described_class::SENIORITY_LEVELS.values).to match_array(%w[intern junior mid senior staff])
      expect(described_class::ENGLISH_LEVELS.values).to match_array(%w[none basic professional fluent])
    end
  end

  describe "enum declarations" do
    it "maps remote enum values as expected" do
      expect(described_class.remotes).to eq(described_class::REMOTE_VALUES.stringify_keys)
    end

    it "maps employment type enum values as expected" do
      expect(described_class.employment_types).to eq(described_class::EMPLOYMENT_TYPES.stringify_keys)
    end
  end

  describe "validators" do
    let(:validators) { described_class.validators }

    it "validates required attributes" do
      attributes = validators.select { |v| v.is_a?(ActiveModel::Validations::PresenceValidator) }
                             .flat_map(&:attributes)

      expect(attributes).to include(
        :source,
        :keyword,
        :work_mode,
        :url,
        :url_hash,
        :first_seen_at,
        :last_seen_at
      )
    end

    it "validates url and url_hash uniqueness" do
      uniqueness = validators.select { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
                             .flat_map(&:attributes)

      expect(uniqueness).to include(:url, :url_hash)
    end
  end
end
