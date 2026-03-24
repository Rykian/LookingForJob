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
      location: {
        preference: [ "remote", "hybrid", "on-site" ],
        city: [ "Nantes" ],
        hybrid: {
          city: [ "Nantes", "Rennes" ],
          remote_days_min_per_week: 3
        },
        on_site: {
          city: [ "Paris" ]
        }
      },
      penalties: {
        unknown_primary_required: 20,
        preference_rank_step: 40,
        not_in_preference: 100,
        city_not_allowed: 100
      },
      bonuses: {
        secondary_match: 10,
        secondary_on_primary_match: 10
      },
      weights: {
        technology: 70,
        location_mode: 20,
        location_city: 10
      }
    }
  end

  it "gives stronger effect to full primary tech match than partial primary match" do
    primary_offer = Offer.new(primary_technologies: [ "ruby", "rails" ], secondary_technologies: [])
    partial_primary_offer = Offer.new(primary_technologies: [ "ruby", "go" ], secondary_technologies: [ "postgresql" ])

    primary_score, primary_details = described_class.tech_subscore(primary_offer, profile)
    partial_primary_score, partial_primary_details = described_class.tech_subscore(partial_primary_offer, profile)

    expect(primary_score).to be > partial_primary_score
    expect(primary_details[:primary_match_ratio]).to eq(1.0)
    expect(partial_primary_details[:primary_match_ratio]).to eq(0.5)
  end

  it "returns score 0 when offer has no primary technologies" do
    offer = Offer.new(primary_technologies: [], secondary_technologies: [ "postgresql" ])

    score, breakdown = described_class.call(offer: offer, profile: profile)

    expect(score).to eq(0)
    expect(breakdown[:technology][:no_primary_technologies]).to eq(true)
    expect(breakdown[:location_mode]).to be_nil
    expect(breakdown[:location_city]).to be_nil
  end

  it "applies unknown primary penalty when offer includes technologies user does not have" do
    offer = Offer.new(primary_technologies: [ "ruby", "elixir" ], secondary_technologies: [])

    score, details = described_class.tech_subscore(offer, profile)

    expect(details[:unknown_required_count]).to eq(1)
    expect(score).to be_between(0, 100)
  end

  it "adds bonuses for matching secondary technologies" do
    offer = Offer.new(primary_technologies: [ "ruby", "postgresql" ], secondary_technologies: [ "postgresql" ])

    score, details = described_class.tech_subscore(offer, profile)

    expect(score).to eq(70)
    expect(details[:bonuses_applied][:secondary_match]).to eq(10)
    expect(details[:bonuses_applied][:secondary_on_primary_match]).to eq(10)
  end

  it "scores location mode by preference rank" do
    remote_offer = Offer.new(remote: "yes")
    hybrid_offer = Offer.new(remote: "hybrid")
    onsite_offer = Offer.new(remote: "no")

    remote_score, = described_class.location_mode_subscore(remote_offer, profile)
    hybrid_score, = described_class.location_mode_subscore(hybrid_offer, profile)
    onsite_score, = described_class.location_mode_subscore(onsite_offer, profile)

    expect(remote_score).to eq(100)
    expect(hybrid_score).to eq(60)
    expect(onsite_score).to eq(20)
  end

  it "returns 0 mode score when offer mode is omitted from preference" do
    profile_without_onsite = profile.deep_dup
    profile_without_onsite[:location][:preference] = [ "remote", "hybrid" ]
    offer = Offer.new(remote: "no")

    score, details = described_class.location_mode_subscore(offer, profile_without_onsite)

    expect(score).to eq(0)
    expect(details[:penalty_reason]).to eq("not_in_preference")
  end

  it "uses location default city when no hybrid override exists" do
    profile_without_hybrid_city = profile.deep_dup
    profile_without_hybrid_city[:location][:hybrid].delete(:city)
    offer = Offer.new(remote: "hybrid", city: "Nantes, France")

    score, details = described_class.location_city_subscore(offer, profile_without_hybrid_city)

    expect(score).to eq(100)
    expect(details[:match_type]).to eq("substring")
  end

  it "uses on-site city override when provided" do
    offer = Offer.new(remote: "no", city: "Paris, France")

    score, details = described_class.location_city_subscore(offer, profile)

    expect(score).to eq(100)
    expect(details[:match_type]).to eq("substring")
  end

  it "forces location mode score to zero for hybrid offers when city score is zero" do
    offer = Offer.new(
      primary_technologies: [ "ruby", "rails" ],
      secondary_technologies: [ "postgresql" ],
      remote: "hybrid",
      city: "Lyon, France",
      hybrid_remote_days_min_per_week: 5
    )

    score, breakdown = described_class.call(offer: offer, profile: profile)

    expect(score).to eq(70)
    expect(breakdown[:location_city][:score]).to eq(0)
    expect(breakdown[:location_mode][:score]).to eq(0)
    expect(breakdown[:location_mode][:forced_to_zero_by_city]).to eq(true)
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
    expect(breakdown[:location_mode]).to be_a(Hash)
    expect(breakdown[:location_city]).to be_a(Hash)
    expect(breakdown[:weights]).to include(:technology, :location_mode, :location_city)
  end
end
