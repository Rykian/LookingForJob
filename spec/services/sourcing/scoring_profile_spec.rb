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
          "remote_hybrid": {
            "importance": "high",
            "preferred_modes": ["yes", "hybrid"],
            "hybrid": {
              "allowed_cities": ["Nantes"]
            }
          }
        }
      JSON

      profile = described_class.load(path)

      expect(profile[:technology][:primary]).to eq(["ruby"])
      expect(profile[:technology][:secondary]).to eq(["postgresql"])
      expect(profile[:remote_hybrid][:importance]).to eq("high")
      expect(profile[:remote_hybrid][:preferred_modes]).to eq(["yes", "hybrid"])
      expect(profile[:remote_hybrid][:hybrid][:allowed_cities]).to eq(["Nantes"])
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
  end
end
