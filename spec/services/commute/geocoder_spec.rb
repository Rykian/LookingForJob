require "rails_helper"

RSpec.describe Commute::Geocoder do
  let(:client) { instance_double(Commute::MapboxClient) }

  describe ".city_for" do
    it "creates and returns a Commute::City on first call" do
      expect(client).to receive(:geocode).with("Nantes").once.and_return(
        { canonical_name: "Nantes", latitude: 47.2173, longitude: -1.5534 }
      )

      city = described_class.city_for("Nantes", client: client)

      expect(city).to be_persisted
      expect(city.name).to eq("Nantes")
      expect(city.normalized_name).to eq("nantes")
      expect(city.latitude.to_f).to eq(47.2173)
      expect(city.longitude.to_f).to eq(-1.5534)
    end

    it "returns the existing row without hitting Mapbox the second time" do
      Commute::City.create!(name: "Nantes", normalized_name: "nantes", latitude: 47.2173, longitude: -1.5534, geocoded_at: Time.current)
      expect(client).not_to receive(:geocode)

      city = described_class.city_for("nantes", client: client)
      expect(city.name).to eq("Nantes")
    end

    it "normalizes variants to the same row (e.g. casing/accents)" do
      expect(client).to receive(:geocode).once.and_return(
        { canonical_name: "Saint-Étienne", latitude: 45.43, longitude: 4.39 }
      )

      first = described_class.city_for("saint etienne", client: client)
      second = described_class.city_for("Saint-Étienne", client: client)
      expect(first.id).to eq(second.id)
      expect(first.name).to eq("Saint-Étienne")
    end

    it "returns nil and does not persist when Mapbox returns no result" do
      expect(client).to receive(:geocode).and_return(nil)
      expect(described_class.city_for("Atlantis", client: client)).to be_nil
      expect(Commute::City.where(normalized_name: "atlantis")).to be_empty
    end

    it "returns nil and logs when Mapbox raises ApiError" do
      expect(client).to receive(:geocode).and_raise(Commute::ApiError, "boom")
      expect(Rails.logger).to receive(:warn).with(/Commute::Geocoder failed/)
      expect(described_class.city_for("Nantes", client: client)).to be_nil
    end

    it "returns nil for blank input without hitting Mapbox" do
      expect(client).not_to receive(:geocode)
      expect(described_class.city_for(nil, client: client)).to be_nil
      expect(described_class.city_for("", client: client)).to be_nil
    end
  end
end
