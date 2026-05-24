require "rails_helper"

RSpec.describe Commute::Duration do
  let(:origin)      { Commute::City.create!(name: "Nantes", normalized_name: "nantes") }
  let(:destination) { Commute::City.create!(name: "Paris",  normalized_name: "paris") }

  it "is unique per (origin, destination, mode) at the DB level" do
    described_class.create!(origin_city: origin, destination_city: destination, mode: "driving", duration_minutes: 240, computed_at: Time.current)
    expect {
      described_class.create!(origin_city: origin, destination_city: destination, mode: "driving", duration_minutes: 250, computed_at: Time.current)
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows the same pair with a different mode" do
    described_class.create!(origin_city: origin, destination_city: destination, mode: "driving", duration_minutes: 240, computed_at: Time.current)
    other = described_class.new(origin_city: origin, destination_city: destination, mode: "cycling", duration_minutes: 800, computed_at: Time.current)
    expect(other).to be_valid
  end

  describe "#fresh?" do
    it "is true when computed_at is within the freshness window" do
      row = described_class.new(computed_at: 1.day.ago)
      expect(row.fresh?).to be true
    end

    it "is false when computed_at is older than the freshness window" do
      row = described_class.new(computed_at: 31.days.ago)
      expect(row.fresh?).to be false
    end

    it "is false when computed_at is nil" do
      row = described_class.new(computed_at: nil)
      expect(row.fresh?).to be false
    end
  end

  describe ".fresh scope" do
    it "returns only rows newer than the freshness window" do
      fresh_row = described_class.create!(origin_city: origin, destination_city: destination, mode: "driving", duration_minutes: 240, computed_at: 1.day.ago)
      _stale_row = described_class.create!(origin_city: origin, destination_city: destination, mode: "cycling", duration_minutes: 800, computed_at: 31.days.ago)
      expect(described_class.fresh).to contain_exactly(fresh_row)
    end
  end
end
