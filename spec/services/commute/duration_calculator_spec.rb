require "rails_helper"

RSpec.describe Commute::DurationCalculator do
  let(:client) { instance_double(Commute::MapboxClient) }
  let(:geocoder) { instance_double(Commute::Geocoder) }
  let(:origin)      { Commute::City.create!(name: "Nantes", normalized_name: "nantes", latitude: 47.21, longitude: -1.55) }
  let(:destination) { Commute::City.create!(name: "Paris",  normalized_name: "paris",  latitude: 48.85, longitude: 2.35) }

  before do
    allow(geocoder).to receive(:city_for).with("Nantes").and_return(origin)
    allow(geocoder).to receive(:city_for).with("Paris").and_return(destination)
  end

  describe ".minutes" do
    it "fetches and persists a fresh row on first call" do
      expect(client).to receive(:duration).with(
        origin: { latitude: 47.21, longitude: -1.55 },
        destination: { latitude: 48.85, longitude: 2.35 },
        mode: "driving"
      ).and_return(240)

      result = described_class.new(client: client, geocoder: geocoder)
                              .minutes(origin: "Nantes", destination: "Paris", mode: "driving")

      expect(result).to eq(240)
      row = Commute::Duration.find_by(origin_city_id: origin.id, destination_city_id: destination.id, mode: "driving")
      expect(row.duration_minutes).to eq(240)
    end

    it "returns the cached row when fresh, without hitting Mapbox" do
      Commute::Duration.create!(origin_city: origin, destination_city: destination, mode: "driving", duration_minutes: 240, computed_at: 1.day.ago)
      expect(client).not_to receive(:duration)

      result = described_class.new(client: client, geocoder: geocoder)
                              .minutes(origin: "Nantes", destination: "Paris", mode: "driving")
      expect(result).to eq(240)
    end

    it "refreshes a stale row and updates duration_minutes in place" do
      Commute::Duration.create!(origin_city: origin, destination_city: destination, mode: "driving", duration_minutes: 240, computed_at: 31.days.ago)
      expect(client).to receive(:duration).and_return(260)

      result = described_class.new(client: client, geocoder: geocoder)
                              .minutes(origin: "Nantes", destination: "Paris", mode: "driving")
      expect(result).to eq(260)
      row = Commute::Duration.find_by(origin_city_id: origin.id, destination_city_id: destination.id, mode: "driving")
      expect(row.duration_minutes).to eq(260)
    end

    it "short-circuits to 0 when origin and destination resolve to the same city" do
      allow(geocoder).to receive(:city_for).with("Paris").and_return(origin)
      expect(client).not_to receive(:duration)

      result = described_class.new(client: client, geocoder: geocoder)
                              .minutes(origin: "Nantes", destination: "Paris", mode: "driving")
      expect(result).to eq(0)
    end

    it "returns nil when either city cannot be geocoded" do
      allow(geocoder).to receive(:city_for).with("Paris").and_return(nil)
      expect(client).not_to receive(:duration)
      result = described_class.new(client: client, geocoder: geocoder)
                              .minutes(origin: "Nantes", destination: "Paris", mode: "driving")
      expect(result).to be_nil
    end

    it "falls back to existing stale duration on API failure" do
      stale = Commute::Duration.create!(origin_city: origin, destination_city: destination, mode: "driving", duration_minutes: 240, computed_at: 31.days.ago)
      expect(client).to receive(:duration).and_raise(Commute::ApiError, "boom")

      result = described_class.new(client: client, geocoder: geocoder)
                              .minutes(origin: "Nantes", destination: "Paris", mode: "driving")
      expect(result).to eq(stale.duration_minutes)
    end
  end
end
