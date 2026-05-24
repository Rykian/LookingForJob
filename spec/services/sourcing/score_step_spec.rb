require "rails_helper"

RSpec.describe Sourcing::ScoreStep do
  Offer = Struct.new(
    :primary_technologies,
    :secondary_technologies,
    :location_mode,
    :city,
    :hybrid_remote_days_min_per_week,
    :commute_city_id,
    keyword_init: true
  )

  let(:profile) do
    {
      technology: {
        primary: ["ruby", "rails"],
        secondary: ["postgresql"],
      },
      location: {
        preference: ["remote", "hybrid", "on-site"],
        hybrid: {
          remote_days_min_per_week: 3,
        },
      },
    }
  end

  describe ".call" do
    it "returns [score, breakdown] tuple" do
      offer = Offer.new(
        primary_technologies: ["ruby", "rails"],
        secondary_technologies: [],
        location_mode: "REMOTE",
        city: "Nantes"
      )

      score, breakdown = described_class.call(offer: offer, profile: profile)

      expect(score).to be_an(Integer)
      expect(score).to be_between(0, 100)
      expect(breakdown).to be_a(Hash)
      expect(breakdown).to include(:technology, :location)
    end

    it "returns score of 0 when offer has no primary technologies" do
      offer = Offer.new(
        primary_technologies: [],
        secondary_technologies: ["postgresql"],
        location_mode: "REMOTE",
        city: "Nantes"
      )

      score, breakdown = described_class.call(offer: offer, profile: profile)

      expect(score).to eq(0)
      expect(breakdown[:technology][:warning]).to eq("offer_has_no_technologies")
    end

    context "technology scoring" do
      it "awards full tech score when all required technologies match" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "REMOTE",
          city: "Nantes"
        )

        score, breakdown = described_class.call(offer: offer, profile: profile)

        expect(score).to eq(100)
        expect(breakdown[:technology]).not_to include(:missing_required_technologies)
      end

      it "penalizes missing required technologies" do
        offer = Offer.new(
          primary_technologies: ["ruby", "go"],
          secondary_technologies: [],
          location_mode: "REMOTE",
          city: "Nantes"
        )

        score, breakdown = described_class.call(offer: offer, profile: profile)

        expect(breakdown[:technology][:missing_required_technologies]).to eq(["go"])
        expect(breakdown[:technology][:penalty_reason]).to eq("missing_required_technologies")
        expect(score).to be < 100
      end

      it "awards bonus for matching secondary technologies" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: ["postgresql"],
          location_mode: "REMOTE",
          city: "Nantes"
        )

        score, breakdown = described_class.call(offer: offer, profile: profile)

        expect(breakdown[:technology][:matching_secondary_technologies]).to include("postgresql")
        expect(breakdown[:technology][:bonus_reason]).to eq("matching_secondary_technologies")
        expect(score).to eq(100)  # Capped at 100
      end

      it "normalizes technology names (case-insensitive and hyphen-agnostic)" do
        offer = Offer.new(
          primary_technologies: ["Ruby", "Rails"],
          secondary_technologies: ["PostgreSQL"],
          location_mode: "REMOTE",
          city: "Nantes"
        )

        score, breakdown = described_class.call(offer: offer, profile: profile)

        expect(breakdown[:technology][:matching_secondary_technologies]).to include("postgresql")
        expect(score).to eq(100)  # Capped at 100
      end

      it "handles multiple missing technologies" do
        offer = Offer.new(
          primary_technologies: ["go", "java"],
          secondary_technologies: [],
          location_mode: "REMOTE",
          city: "Nantes"
        )

        score, breakdown = described_class.call(offer: offer, profile: profile)

        expect(breakdown[:technology][:missing_required_technologies].size).to eq(2)
        expect(score).to eq(0)
      end

      it "handles multiple matching secondary technologies" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: ["postgresql", "redis"],
          location_mode: "REMOTE",
          city: "Nantes"
        )

        profile_with_redis = profile.deep_dup
        profile_with_redis[:technology][:secondary] << "redis"

        score, breakdown = described_class.call(offer: offer, profile: profile_with_redis)

        expect(breakdown[:technology][:matching_secondary_technologies].size).to eq(2)
        expect(score).to eq(100)  # Capped at 100
      end
    end

    context "location scoring" do
      it "awards 100 for most preferred location (remote)" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "REMOTE",
          city: nil
        )

        score, breakdown = described_class.call(offer: offer, profile: profile)

        expect(score).to eq(100)
        expect(breakdown[:location]).to be_empty
      end

      it "deducts points for lower preference rank" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "hybrid",
          city: "Nantes",
          hybrid_remote_days_min_per_week: 3
        )

        score, breakdown = described_class.call(offer: offer, profile: profile)

        expect(breakdown[:location][:penalty_reason]).to eq("lower_preference_rank")
        expect(breakdown[:location][:rank]).to eq(1)
        expect(breakdown[:location][:malus]).to eq(20)  # rank * 20
        expect(score).to eq(60)  # 100 - 20 (hybrid remote) - 20 (rank)
      end

      it "returns 0 score when offer mode is not in preference list" do
        profile_no_onsite = profile.deep_dup
        profile_no_onsite[:location][:preference] = ["remote", "hybrid"]

        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "ON_SITE",
          city: "Paris"
        )

        score, breakdown = described_class.call(offer: offer, profile: profile_no_onsite)

        expect(breakdown[:location][:penalty_reason]).to eq("not_in_preference")
        expect(score).to eq(0)
      end

      it "returns 0 score when hybrid remote days are insufficient" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "HYBRID",
          city: "Nantes",
          hybrid_remote_days_min_per_week: 2
        )

        score, breakdown = described_class.call(offer: offer, profile: profile)

        expect(breakdown[:location][:penalty_reason]).to eq("hybrid_remote_days_insufficient")
        expect(score).to eq(0)
      end

      it "deducts points for hybrid with match at minimum remote days" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "HYBRID",
          city: "Nantes",
          hybrid_remote_days_min_per_week: 3
        )

        score, breakdown = described_class.call(offer: offer, profile: profile)

        # Both remote days penalty (20) and rank penalty (20) are applied
        expect(breakdown[:location][:penalty_reason]).to eq("lower_preference_rank")
        expect(score).to eq(60)
      end

      it "deducts additional malus for hybrid with fewer remote days than optimal" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "HYBRID",
          city: "Nantes",
          hybrid_remote_days_min_per_week: 2
        )

        profile_min_2_days = profile.deep_dup
        profile_min_2_days[:location][:hybrid][:remote_days_min_per_week] = 2

        score, breakdown = described_class.call(offer: offer, profile: profile_min_2_days)

        # Malus for remote days: (5-2)*10 = 30, then rank malus: 1*20 = 20
        # Final score: 100 - 30 - 20 = 50
        # Last penalty_reason set wins: "lower_preference_rank"
        expect(breakdown[:location][:penalty_reason]).to eq("lower_preference_rank")
        expect(breakdown[:location][:malus]).to eq(20)  # The rank malus
        expect(score).to eq(50)
      end
    end

    context "location_mode values" do
      it 'accepts "remote"' do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "remote"
        )

        score, = described_class.call(offer: offer, profile: profile)

        expect(score).to eq(100)
      end

      it 'accepts "on-site"' do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "on-site",
          city: "Paris"
        )

        score, = described_class.call(offer: offer, profile: profile)

        expect(score).to be_between(0, 100)
      end

      it 'accepts "hybrid"' do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "hybrid",
          city: "Nantes",
          hybrid_remote_days_min_per_week: 3
        )

        score, = described_class.call(offer: offer, profile: profile)

        # Both remote days penalty (20) and rank penalty (20) are applied
        expect(score).to eq(60)
      end

      it "defaults unknown values to on-site" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "UNKNOWN",
          city: "Paris"
        )

        score, = described_class.call(offer: offer, profile: profile)

        expect(score).to be_between(0, 100)
      end
    end

    context "score bounding" do
      it "bounds score to maximum of 100" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: ["postgresql"],
          location_mode: "REMOTE",
          city: nil
        )

        score, = described_class.call(offer: offer, profile: profile)

        expect(score).to eq(100)
      end

      it "bounds score to minimum of 0" do
        offer = Offer.new(
          primary_technologies: [],
          secondary_technologies: [],
          location_mode: "remote",
          city: nil
        )

        score, = described_class.call(offer: offer, profile: profile)

        expect(score).to eq(0)
      end
    end

    context "commute scoring" do
      let(:origin) { Commute::City.create!(name: "Nantes", normalized_name: "nantes", latitude: 47.21, longitude: -1.55) }
      let(:destination) { Commute::City.create!(name: "Paris", normalized_name: "paris", latitude: 48.85, longitude: 2.35) }
      let(:profile_with_commute) do
        profile.deep_merge(location: { commute: { origin_city: "Nantes", max_minutes: 45, mode: "driving" } })
      end

      it "skips when profile has no commute section" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "REMOTE",
          city: nil,
          commute_city_id: nil
        )

        _, breakdown = described_class.call(offer: offer, profile: profile)
        expect(breakdown[:commute]).to include(skipped: true, reason: "no_profile_commute")
      end

      it "skips when offer has no commute_city_id" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "REMOTE",
          city: nil,
          commute_city_id: nil
        )

        _, breakdown = described_class.call(offer: offer, profile: profile_with_commute)
        expect(breakdown[:commute]).to include(skipped: true, reason: "offer_has_no_commute_city")
      end

      it "does not penalize when duration is within max" do
        Commute::Duration.create!(origin_city: origin, destination_city: destination, mode: "driving", duration_minutes: 30, computed_at: Time.current)
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "REMOTE",
          city: "Paris",
          commute_city_id: destination.id
        )

        score, breakdown = described_class.call(offer: offer, profile: profile_with_commute)
        expect(breakdown[:commute]).to include(minutes: 30, max_minutes: 45, within_max: true)
        expect(score).to eq(100)
      end

      it "applies -100 penalty when duration exceeds max" do
        Commute::Duration.create!(origin_city: origin, destination_city: destination, mode: "driving", duration_minutes: 240, computed_at: Time.current)
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "REMOTE",
          city: "Paris",
          commute_city_id: destination.id
        )

        score, breakdown = described_class.call(offer: offer, profile: profile_with_commute)
        expect(breakdown[:commute]).to include(minutes: 240, max_minutes: 45, penalty_reason: "over_max_commute")
        expect(score).to eq(0)
      end

      it "skips when origin city has not been geocoded" do
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "REMOTE",
          city: "Paris",
          commute_city_id: destination.id
        )

        _, breakdown = described_class.call(offer: offer, profile: profile_with_commute)
        expect(breakdown[:commute]).to include(skipped: true, reason: "origin_not_geocoded")
      end

      it "skips when no duration row exists for the current mode" do
        origin
        offer = Offer.new(
          primary_technologies: ["ruby", "rails"],
          secondary_technologies: [],
          location_mode: "REMOTE",
          city: "Paris",
          commute_city_id: destination.id
        )

        _, breakdown = described_class.call(offer: offer, profile: profile_with_commute)
        expect(breakdown[:commute]).to include(skipped: true, reason: "no_duration_row")
      end
    end
  end
end
