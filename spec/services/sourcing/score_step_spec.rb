require "rails_helper"

RSpec.describe Sourcing::ScoreStep do
  Offer = Struct.new(
    :primary_technologies,
    :secondary_technologies,
    :remote,
    :city,
    :hybrid_remote_days_min_per_week,
    keyword_init: true
  )

  let(:profile) do
    {
      technology: {
        primary: [ "ruby", "rails" ],
        secondary: [ "postgresql" ]
      },
      remote_hybrid: {
        importance: "high",
        preferred_modes: [ "yes", "hybrid" ],
        hybrid: {
          allowed_cities: [ "Nantes", "Rennes" ]
        }
      }
    }
  end

  it "gives stronger effect to primary tech match than secondary" do
    primary_offer = Offer.new(primary_technologies: [ "ruby", "rails" ], secondary_technologies: [])
    secondary_offer = Offer.new(primary_technologies: [], secondary_technologies: [ "postgresql" ])

    primary_score, primary_details = described_class.tech_subscore(primary_offer, profile)
    secondary_score, secondary_details = described_class.tech_subscore(secondary_offer, profile)

    expect(primary_score).to be > secondary_score
    expect(primary_details[:bonus]).to eq(60)
    expect(secondary_details[:secondary_bonus]).to eq(20)
  end

  it "applies malus when offer primary includes technologies user does not have" do
    offer = Offer.new(primary_technologies: [ "ruby", "elixir" ], secondary_technologies: [])

    score, details = described_class.tech_subscore(offer, profile)

    expect(details[:malus]).to eq(-20)
    expect(score).to be >= 0
  end

  it "increases hybrid score with more remote days" do
    base_offer = Offer.new(remote: "hybrid", city: "Nantes")
    low_days_offer = Offer.new(remote: "hybrid", city: "Nantes", hybrid_remote_days_min_per_week: 2)
    high_days_offer = Offer.new(remote: "hybrid", city: "Nantes", hybrid_remote_days_min_per_week: 5)

    base_score, = described_class.remote_subscore(base_offer, profile)
    low_days_score, = described_class.remote_subscore(low_days_offer, profile)
    high_days_score, = described_class.remote_subscore(high_days_offer, profile)

    expect(low_days_score).to be >= base_score
    expect(high_days_score).to be > low_days_score
  end

  it "returns final score and breakdown" do
    offer = Offer.new(
      primary_technologies: [ "ruby", "rails" ],
      secondary_technologies: [ "postgresql" ],
      remote: "hybrid",
      city: "Nantes",
      hybrid_remote_days_min_per_week: 4
    )

    score, breakdown = described_class.call(offer: offer, profile: profile)

    expect(score).to be_a(Integer)
    expect(score).to be_between(0, 100)
    expect(breakdown[:technology]).to be_a(Hash)
    expect(breakdown[:remote_hybrid]).to be_a(Hash)
  end

  it "applies city bonus when profile city is included in offer city string" do
    offer = Offer.new(
      remote: "hybrid",
      city: "Paris, Ile-de-France, France",
      hybrid_remote_days_min_per_week: 3
    )

    profile_with_paris = profile.deep_dup
    profile_with_paris[:remote_hybrid][:hybrid][:allowed_cities] = [ "Paris" ]

    score, details = described_class.remote_subscore(offer, profile_with_paris)

    expect(score).to be > 0
    expect(details[:city_bonus]).to eq(10)
  end
end
