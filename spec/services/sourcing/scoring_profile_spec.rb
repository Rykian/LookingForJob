require "rails_helper"

RSpec.describe Sourcing::ScoringProfile do
  describe ".load" do
    it "loads and symbolizes a valid profile json" do
      path = Rails.root.join("tmp", "scoring_profile_spec_valid.json")
      File.write(path, <<~JSON)
        {
          "technology": {
            "primary": ["ruby"],
            "secondary": ["postgresql"]
          },
          "location": {
            "preference": ["remote", "hybrid", "on-site"],
            "city": ["Nantes"],
            "hybrid": {
              "city": ["Nantes"],
              "remote_days_min_per_week": 3
            },
            "on_site": {
              "city": ["Paris"]
            }
          },
          "penalties": {
            "unknown_primary_required": 20,
            "preference_rank_step": 40,
            "not_in_preference": 100,
            "city_not_allowed": 100
          },
          "bonuses": {
            "secondary_match": 10,
            "secondary_on_primary_match": 10
          },
          "weights": {
            "technology": 70,
            "location_mode": 20,
            "location_city": 10
          }
        }
      JSON

      profile = described_class.load(path)

      expect(profile[:technology][:primary]).to eq(["ruby"])
      expect(profile[:technology][:secondary]).to eq(["postgresql"])
      expect(profile[:location][:preference]).to eq(["remote", "hybrid", "on-site"])
      expect(profile[:location][:hybrid][:city]).to eq(["Nantes"])
      expect(profile[:weights][:technology]).to eq(70)
    ensure
      File.delete(path) if File.exist?(path)
    end

    it "raises a clear error when profile file is missing" do
      path = Rails.root.join("tmp", "scoring_profile_spec_missing.json")

      expect { described_class.load(path) }.to raise_error(RuntimeError, /Scoring profile not found/)
    end

    it "raises a clear error when profile json is invalid" do
      path = Rails.root.join("tmp", "scoring_profile_spec_invalid.json")
      File.write(path, "{invalid json")

      expect { described_class.load(path) }.to raise_error(RuntimeError, /Invalid JSON/)
    ensure
      File.delete(path) if File.exist?(path)
    end

    it "raises when required keys are missing" do
      path = Rails.root.join("tmp", "scoring_profile_spec_missing_keys.json")
      File.write(path, <<~JSON)
        {
          "technology": {
            "primary": ["ruby"]
          }
        }
      JSON

      expect { described_class.load(path) }.to raise_error(RuntimeError, /Missing technology.secondary/)
    ensure
      File.delete(path) if File.exist?(path)
    end

    it "raises when location preference is missing" do
      path = Rails.root.join("tmp", "scoring_profile_spec_missing_v3_keys.json")
      File.write(path, <<~JSON)
        {
          "technology": {
            "primary": ["ruby"],
            "secondary": ["postgresql"]
          },
          "location": {
            "city": ["Nantes"]
          },
          "penalties": {
            "unknown_primary_required": 20,
            "preference_rank_step": 40,
            "not_in_preference": 100,
            "city_not_allowed": 100
          },
          "bonuses": {
            "secondary_match": 10,
            "secondary_on_primary_match": 10
          },
          "weights": {
            "technology": 70,
            "location_mode": 20,
            "location_city": 10
          }
        }
      JSON

      expect { described_class.load(path) }.to raise_error(RuntimeError, /Missing location.preference/)
    ensure
      File.delete(path) if File.exist?(path)
    end

    it "raises when location preference contains invalid values" do
      path = Rails.root.join("tmp", "scoring_profile_spec_invalid_preference.json")
      File.write(path, <<~JSON)
        {
          "technology": {
            "primary": ["ruby"],
            "secondary": ["postgresql"]
          },
          "location": {
            "preference": ["remote", "office"],
            "hybrid": {
              "remote_days_min_per_week": 3
            }
          },
          "penalties": {
            "unknown_primary_required": 20,
            "preference_rank_step": 40,
            "not_in_preference": 100,
            "city_not_allowed": 100
          },
          "bonuses": {
            "secondary_match": 10,
            "secondary_on_primary_match": 10
          },
          "weights": {
            "technology": 70,
            "location_mode": 20,
            "location_city": 10
          }
        }
      JSON

      expect { described_class.load(path) }.to raise_error(RuntimeError, /Invalid location.preference/)
    ensure
      File.delete(path) if File.exist?(path)
    end
  end
end
