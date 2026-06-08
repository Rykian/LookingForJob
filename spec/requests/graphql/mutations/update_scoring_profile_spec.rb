require "rails_helper"

RSpec.describe "GraphQL mutation updateScoringProfile", type: :request do
  it "writes validated profile data" do
    path = Rails.root.join("tmp", "test_scoring_profile.json")
    stub_const("Sourcing::ScoringProfile::PROFILE_PATH", path)

    mutation = <<~GRAPHQL
      mutation UpdateScoringProfile($profile: JSON!) {
        updateScoringProfile(input: { profile: $profile }) {
          profile
        }
      }
    GRAPHQL

    profile = {
      technology: {
        primary: ["ruby"],
        secondary: ["postgresql"],
      },
      location: {
        preference: ["remote", "hybrid", "on-site"],
        city: ["Paris"],
        hybrid: {
          city: ["Paris"],
          remote_days_min_per_week: 3,
        },
        on_site: {
          city: ["Lyon"],
        },
      },
      penalties: {
        unknown_primary_required: 20,
        preference_rank_step: 40,
        not_in_preference: 100,
        city_not_allowed: 100,
      },
      bonuses: {
        secondary_match: 10,
        secondary_on_primary_match: 10,
      },
      weights: {
        technology: 70,
        location_mode: 20,
        location_city: 10,
      },
    }

    result = post_graphql(query: mutation, variables: { profile: profile })

    expect(result["errors"]).to be_nil
    returned_profile = result.dig("data", "updateScoringProfile", "profile")
    expect(returned_profile.dig("technology", "primary")).to eq(["ruby"])
    expect(File.exist?(path)).to eq(true)

    written = JSON.parse(File.read(path))
    expect(written.dig("technology", "primary")).to eq(["ruby"])
    expect(written.dig("location", "hybrid", "city")).to eq(["Paris"])
  ensure
    File.delete(path) if File.exist?(path)
  end
end
