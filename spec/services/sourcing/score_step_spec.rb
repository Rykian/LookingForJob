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
        secondary: [ "postgresql" ],
        weights: {
          primary_coverage: 0.75,
          secondary_coverage: 0.15,
          unknown_penalty: 0.10
        }
      },
      remote_hybrid: {
        importance: "high",
        preferred_modes: [ "yes", "hybrid" ],
        hybrid: {
          allowed_cities: [ "Nantes", "Rennes" ],
          hybrid_remote_days_min_per_week: 3,
          days_weight: 0.35
        }
      },
      weights: {
        technology: 70,
        remote_hybrid: 20,
        location: 10
      }
    }
  end

  it "gives stronger effect to full primary tech match than partial primary match" do
    primary_offer = Offer.new(primary_technologies: [ "ruby", "rails" ], secondary_technologies: [])
    partial_primary_offer = Offer.new(primary_technologies: [ "ruby", "go" ], secondary_technologies: [ "postgresql" ])

    primary_score, primary_details = described_class.tech_subscore(primary_offer, profile)
    partial_primary_score, partial_primary_details = described_class.tech_subscore(partial_primary_offer, profile)

    expect(primary_score).to be > partial_primary_score
    expect(primary_details[:primary_coverage]).to eq(1.0)
    expect(partial_primary_details[:primary_coverage]).to eq(0.5)
  end

  it "returns an extremely low final score when there is no primary technology overlap" do
    offer = Offer.new(
      primary_technologies: [ "golang", "kubernetes" ],
      secondary_technologies: [ "postgresql" ],
      remote: "hybrid",
      city: "Rennes",
      hybrid_remote_days_min_per_week: 5
    )

    score, breakdown = described_class.call(offer: offer, profile: profile)

    expect(score).to eq(0)
    expect(breakdown[:technology][:no_primary_match]).to eq(true)
    expect(breakdown[:gate_reason]).to eq("no_primary_overlap")
    expect(breakdown[:remote_hybrid]).to be_nil
    expect(breakdown[:location]).to be_nil
  end

  it "applies unknown primary penalty when offer includes technologies user does not have" do
    offer = Offer.new(primary_technologies: [ "ruby", "elixir" ], secondary_technologies: [])

    score, details = described_class.tech_subscore(offer, profile)

    expect(details[:unknown_primary_ratio]).to eq(0.5)
    expect(score).to be_between(0, 100)
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

  it "gives location points to hybrid only when city is in allowed list" do
    matching_offer = Offer.new(remote: "hybrid", city: "Rennes, Brittany, France")
    non_matching_offer = Offer.new(remote: "hybrid", city: "Lyon, France")

    matching_score, matching_details = described_class.location_subscore(matching_offer, profile)
    non_matching_score, non_matching_details = described_class.location_subscore(non_matching_offer, profile)

    expect(matching_score).to eq(100)
    expect(matching_details[:match_type]).to eq("substring")
    expect(non_matching_score).to eq(0)
    expect(non_matching_details[:match_type]).to eq("none")
  end

  it "keeps location neutral for non-hybrid offers" do
    offer = Offer.new(remote: "yes", city: "Anywhere")

    score, details = described_class.location_subscore(offer, profile)

    expect(score).to eq(100)
    expect(details[:match_type]).to eq("not_hybrid")
  end

  it "forces remote_hybrid score to zero for hybrid offers when location score is zero" do
    offer = Offer.new(
      primary_technologies: [ "ruby", "rails" ],
      secondary_technologies: [ "postgresql" ],
      remote: "hybrid",
      city: "Lyon, France",
      hybrid_remote_days_min_per_week: 5
    )

    score, breakdown = described_class.call(offer: offer, profile: profile)

    expect(score).to eq(63)
    expect(breakdown[:location][:score]).to eq(0)
    expect(breakdown[:remote_hybrid][:score]).to eq(0)
    expect(breakdown[:remote_hybrid][:forced_to_zero_by_location]).to eq(true)
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
    expect(breakdown[:location]).to be_a(Hash)
    expect(breakdown[:weights]).to include(:technology, :remote_hybrid, :location)
  end
end
