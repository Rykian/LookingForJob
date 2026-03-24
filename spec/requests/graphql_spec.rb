require "rails_helper"

RSpec.describe "GraphQL API", type: :request do
  def post_graphql(query:, variables: {})
    post "/graphql", params: { query: query, variables: variables }, as: :json
    JSON.parse(response.body)
  end

  describe "query jobOffers" do
    it "returns paginated offers and applies filters" do
      first_offer = JobOffer.create!(
        source: "linkedin",
        url: "https://example.com/offers/1",
        url_hash: "hash-1",
        first_seen_at: 2.days.ago,
        last_seen_at: 2.days.ago,
        remote: "yes",
        scored_at: Time.current,
        title: "Backend Engineer"
      )

      JobOffer.create!(
        source: "welcome_to_the_jungle",
        url: "https://example.com/offers/2",
        url_hash: "hash-2",
        first_seen_at: 1.day.ago,
        last_seen_at: 1.day.ago,
        remote: "hybrid",
        title: "Frontend Engineer"
      )

      query = <<~GRAPHQL
        query JobOffers($page: Int!, $perPage: Int!, $source: String, $remote: String, $scored: Boolean) {
          jobOffers(page: $page, perPage: $perPage, source: $source, remote: $remote, scored: $scored) {
            totalCount
            totalPages
            nodes {
              id
              source
              remote
              title
            }
          }
        }
      GRAPHQL

      result = post_graphql(
        query: query,
        variables: {
          page: 1,
          perPage: 25,
          source: "linkedin",
          remote: "yes",
          scored: true
        }
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "jobOffers", "totalCount")).to eq(1)
      expect(result.dig("data", "jobOffers", "totalPages")).to eq(1)
      node = result.dig("data", "jobOffers", "nodes").first
      expect(node["id"]).to eq(first_offer.id.to_s)
      expect(node["source"]).to eq("linkedin")
      expect(node["remote"]).to eq("yes")
      expect(node["title"]).to eq("Backend Engineer")
    end

    it "sorts offers by score in descending order" do
      low = JobOffer.create!(
        source: "linkedin",
        url: "https://example.com/offers/sort-low",
        url_hash: "hash-sort-low",
        first_seen_at: 2.days.ago,
        last_seen_at: 2.days.ago,
        score: 10
      )

      high = JobOffer.create!(
        source: "linkedin",
        url: "https://example.com/offers/sort-high",
        url_hash: "hash-sort-high",
        first_seen_at: 1.day.ago,
        last_seen_at: 1.day.ago,
        score: 90
      )

      query = <<~GRAPHQL
        query JobOffers($page: Int!, $perPage: Int!, $sortBy: String, $sortDirection: String) {
          jobOffers(page: $page, perPage: $perPage, sortBy: $sortBy, sortDirection: $sortDirection) {
            nodes {
              id
              score
            }
          }
        }
      GRAPHQL

      result = post_graphql(
        query: query,
        variables: {
          page: 1,
          perPage: 25,
          sortBy: "score",
          sortDirection: "desc"
        }
      )

      expect(result["errors"]).to be_nil
      node_ids = result.dig("data", "jobOffers", "nodes").map { |node| node["id"] }
      expect(node_ids.index(high.id.to_s)).to be < node_ids.index(low.id.to_s)
    end
  end

  describe "query dashboardMetrics" do
    it "returns counts and source aggregates" do
      JobOffer.create!(
        source: "linkedin",
        url: "https://example.com/offers/3",
        url_hash: "hash-3",
        first_seen_at: Time.current,
        last_seen_at: Time.current,
        fetched_at: Time.current,
        enriched_at: Time.current,
        scored_at: Time.current,
        score: 80
      )

      query = <<~GRAPHQL
        query DashboardMetrics {
          dashboardMetrics {
            total
            fetched
            enriched
            scored
            averageScore
            topSources {
              source
              count
            }
          }
        }
      GRAPHQL

      result = post_graphql(query: query)

      expect(result["errors"]).to be_nil
      metrics = result.dig("data", "dashboardMetrics")
      expect(metrics["total"]).to be >= 1
      expect(metrics["fetched"]).to be >= 1
      expect(metrics["enriched"]).to be >= 1
      expect(metrics["scored"]).to be >= 1
      expect(metrics["averageScore"]).to be_a(Numeric)
      expect(metrics["topSources"]).to be_an(Array)
      expect(metrics["topSources"]).not_to be_empty
    end
  end

  describe "mutation launchDiscovery" do
    it "enqueues launch discovery job" do
      allow(Sourcing::LaunchDiscoveryJob).to receive(:perform_later)

      mutation = <<~GRAPHQL
        mutation LaunchDiscovery {
          launchDiscovery(input: {}) {
            message
          }
        }
      GRAPHQL

      result = post_graphql(query: mutation)

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "launchDiscovery", "message")).to eq("Discovery job enqueued.")
      expect(Sourcing::LaunchDiscoveryJob).to have_received(:perform_later)
    end
  end

  describe "mutation updateScoringProfile" do
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
          secondary: ["postgresql"]
        },
        location: {
          preference: ["remote", "hybrid", "on-site"],
          city: ["Paris"],
          hybrid: {
            city: ["Paris"],
            remote_days_min_per_week: 3
          },
          on_site: {
            city: ["Lyon"]
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

  describe "mutation recomputeOfferScores" do
    it "enqueues one scoring job per offer" do
      first = JobOffer.create!(
        source: "linkedin",
        url: "https://example.com/offers/recompute-1",
        url_hash: "hash-recompute-1",
        first_seen_at: Time.current,
        last_seen_at: Time.current
      )

      second = JobOffer.create!(
        source: "linkedin",
        url: "https://example.com/offers/recompute-2",
        url_hash: "hash-recompute-2",
        first_seen_at: Time.current,
        last_seen_at: Time.current
      )

      allow(Sourcing::ScoringJob).to receive(:perform_later)

      mutation = <<~GRAPHQL
        mutation RecomputeOfferScores {
          recomputeOfferScores(input: {}) {
            message
            enqueuedCount
          }
        }
      GRAPHQL

      result = post_graphql(query: mutation)

      expect(result["errors"]).to be_nil
      payload = result.dig("data", "recomputeOfferScores")
      expect(payload["enqueuedCount"]).to eq(2)
      expect(payload["message"]).to eq("Score recomputation enqueued for 2 offers.")
      expect(Sourcing::ScoringJob).to have_received(:perform_later).with(url_hash: first.url_hash)
      expect(Sourcing::ScoringJob).to have_received(:perform_later).with(url_hash: second.url_hash)
    end
  end
end
