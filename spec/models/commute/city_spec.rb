require "rails_helper"

RSpec.describe Commute::City do
  describe ".normalize" do
    it "lowercases, strips accents and trims" do
      expect(described_class.normalize("Saint-Étienne")).to eq("saint-etienne")
      expect(described_class.normalize("  Nantes  ")).to eq("nantes")
      expect(described_class.normalize("Île-de-France")).to eq("ile-de-france")
    end

    it "returns empty string for nil" do
      expect(described_class.normalize(nil)).to eq("")
    end
  end

  it "enforces uniqueness of normalized_name at the DB level" do
    described_class.create!(name: "Nantes", normalized_name: "nantes")
    expect {
      described_class.create!(name: "Nantes", normalized_name: "nantes")
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
