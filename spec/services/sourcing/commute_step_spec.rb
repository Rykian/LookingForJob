require "rails_helper"

RSpec.describe Sourcing::CommuteStep do
  let(:profile) do
    {
      location: {
        commute: {
          origin_city: "Nantes",
          max_minutes: 45,
          mode: "driving",
        },
      },
    }
  end

  let(:geocoder) { instance_double(Commute::Geocoder) }
  let(:calculator) { instance_double(Commute::DurationCalculator) }
  let(:nantes) { Commute::City.create!(name: "Nantes", normalized_name: "nantes", latitude: 47.21, longitude: -1.55) }
  let(:paris)  { Commute::City.create!(name: "Paris",  normalized_name: "paris",  latitude: 48.85, longitude: 2.35) }

  def make_offer(**overrides)
    JobOffer.create!({
      source: "linkedin",
      url: "https://example.com/jobs/commute-#{SecureRandom.hex(4)}",
      url_hash: Digest::SHA256.hexdigest(SecureRandom.hex),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      location_mode: "hybrid",
      city: "Paris",
    }.merge(overrides))
  end

  it "skips when profile has no commute config" do
    offer = make_offer
    result = described_class.new(geocoder: geocoder, calculator: calculator).call(offer: offer, profile: {})
    expect(result.status).to eq(:skipped)
    expect(result.commute_city_id).to be_nil
  end

  it "skips when offer is remote" do
    offer = make_offer(location_mode: "remote", city: nil)
    expect(geocoder).not_to receive(:city_for)
    result = described_class.new(geocoder: geocoder, calculator: calculator).call(offer: offer, profile: profile)
    expect(result.status).to eq(:skipped)
  end

  it "skips when offer has no city" do
    offer = make_offer(city: nil)
    expect(geocoder).not_to receive(:city_for)
    result = described_class.new(geocoder: geocoder, calculator: calculator).call(offer: offer, profile: profile)
    expect(result.status).to eq(:skipped)
  end

  it "skips when destination geocoding fails" do
    offer = make_offer(city: "Atlantis")
    allow(geocoder).to receive(:city_for).with("Atlantis").and_return(nil)
    expect(calculator).not_to receive(:minutes)
    result = described_class.new(geocoder: geocoder, calculator: calculator).call(offer: offer, profile: profile)
    expect(result.status).to eq(:skipped)
  end

  it "returns the canonical city when Mapbox normalizes the name" do
    offer = make_offer(city: "saint etienne")
    saint_etienne = Commute::City.create!(name: "Saint-Étienne", normalized_name: "saint-etienne", latitude: 45.43, longitude: 4.39)
    allow(geocoder).to receive(:city_for).with("saint etienne").and_return(saint_etienne)
    allow(calculator).to receive(:minutes).and_return(180)

    result = described_class.new(geocoder: geocoder, calculator: calculator).call(offer: offer, profile: profile)
    expect(result.status).to eq(:ok)
    expect(result.canonical_city).to eq("Saint-Étienne")
    expect(result.commute_city_id).to eq(saint_etienne.id)
    expect(result.duration_minutes).to eq(180)
  end

  it "passes origin/destination/mode through to the calculator" do
    offer = make_offer(city: "Paris")
    allow(geocoder).to receive(:city_for).with("Paris").and_return(paris)
    expect(calculator).to receive(:minutes).with(origin: "Nantes", destination: "Paris", mode: "driving").and_return(240)

    result = described_class.new(geocoder: geocoder, calculator: calculator).call(offer: offer, profile: profile)
    expect(result.duration_minutes).to eq(240)
  end
end
