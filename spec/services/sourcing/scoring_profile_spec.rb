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
            "hybrid": {
              "remote_days_min_per_week": 3
            }
          }
        }
      JSON

      profile = described_class.load(path)

      expect(profile[:technology][:primary]).to eq(["ruby"])
      expect(profile[:technology][:secondary]).to eq(["postgresql"])
      expect(profile[:location][:preference]).to eq(["remote", "hybrid", "on-site"])
      expect(profile[:location][:hybrid][:remote_days_min_per_week]).to eq(3)
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
          "location": {}
        }
      JSON

      expect { described_class.load(path) }.to raise_error(RuntimeError, /Missing location.preference/)
    ensure
      File.delete(path) if File.exist?(path)
    end

    it "accepts a valid commute section nested under location" do
      path = Rails.root.join("tmp", "scoring_profile_spec_commute_valid.json")
      File.write(path, <<~JSON)
        {
          "technology": { "primary": ["ruby"], "secondary": [] },
          "location": { "preference": ["remote"], "commute": { "origin_city": "Nantes", "max_minutes": 45, "mode": "driving" } }
        }
      JSON

      profile = described_class.load(path)
      expect(profile.dig(:location, :commute)).to eq({ origin_city: "Nantes", max_minutes: 45, mode: "driving" })
    ensure
      File.delete(path) if File.exist?(path)
    end

    it "raises when commute mode is invalid" do
      path = Rails.root.join("tmp", "scoring_profile_spec_commute_bad_mode.json")
      File.write(path, <<~JSON)
        {
          "technology": { "primary": ["ruby"], "secondary": [] },
          "location": { "preference": ["remote"], "commute": { "origin_city": "Nantes", "max_minutes": 45, "mode": "transit" } }
        }
      JSON

      expect { described_class.load(path) }.to raise_error(RuntimeError, /Invalid commute.mode/)
    ensure
      File.delete(path) if File.exist?(path)
    end

    it "raises when commute.max_minutes is missing or non-positive" do
      path = Rails.root.join("tmp", "scoring_profile_spec_commute_no_max.json")
      File.write(path, <<~JSON)
        {
          "technology": { "primary": ["ruby"], "secondary": [] },
          "location": { "preference": ["remote"], "commute": { "origin_city": "Nantes", "max_minutes": 0, "mode": "driving" } }
        }
      JSON

      expect { described_class.load(path) }.to raise_error(RuntimeError, /Missing commute.max_minutes/)
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
            "hybrid": { "remote_days_min_per_week": 3 }
          }
        }
      JSON

      expect { described_class.load(path) }.to raise_error(RuntimeError, /Invalid location.preference/)
    ensure
      File.delete(path) if File.exist?(path)
    end
  end
end
