require "rails_helper"

RSpec.describe "GraphQL API", type: :request do
  def post_graphql(query:, variables: {})
    post "/graphql", params: { query: query, variables: variables }, as: :json
    JSON.parse(response.body)
  end

  describe "query jobOffers" do
    it "returns paginated offers and applies filters" do
      first_offer = create(:job_offer, :remote,
        last_seen_at: 2.days.ago,
        title: "Backend Engineer",
        steps_details: {
          "discovery" => { "at" => 2.days.ago.iso8601, "version" => 1 },
          "score" => { "at" => Time.current.iso8601, "version" => 2 },
        })

      create(:job_offer, :hybrid,
        source: "welcome_to_the_jungle",
        last_seen_at: 1.day.ago,
        title: "Frontend Engineer")

      query = <<~GRAPHQL
        query JobOffers($page: Int!, $perPage: Int!, $source: String, $locationModes: [LocationModeEnum!]) {
          jobOffers(page: $page, perPage: $perPage, source: $source, locationModes: $locationModes) {
            totalCount
            totalPages
            nodes {
              id
              source
              locationMode
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
          locationModes: ["REMOTE", "HYBRID"],
        }
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "jobOffers", "totalCount")).to eq(1)
      expect(result.dig("data", "jobOffers", "totalPages")).to eq(1)
      node = result.dig("data", "jobOffers", "nodes").first
      expect(node["id"]).to eq(first_offer.id.to_s)
      expect(node["source"]).to eq("linkedin")
      expect(node["locationMode"]).to eq("REMOTE")
      expect(node["title"]).to eq("Backend Engineer")
    end

    it "filters offers by firstSeenAt range" do
      in_range = create(:job_offer, :with_discovery_step, discovered_at: 2.days.ago)
      create(:job_offer, :with_discovery_step, discovered_at: 20.days.ago)

      query = <<~GRAPHQL
        query JobOffers($page: Int!, $perPage: Int!, $firstSeenAfter: ISO8601DateTime, $firstSeenBefore: ISO8601DateTime) {
          jobOffers(page: $page, perPage: $perPage, firstSeenAfter: $firstSeenAfter, firstSeenBefore: $firstSeenBefore) {
            totalCount
            nodes {
              id
            }
          }
        }
      GRAPHQL

      result = post_graphql(
        query: query,
        variables: {
          page: 1,
          perPage: 25,
          firstSeenAfter: 7.days.ago.iso8601,
          firstSeenBefore: Time.current.iso8601,
        }
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "jobOffers", "totalCount")).to eq(1)
      expect(result.dig("data", "jobOffers", "nodes").first["id"]).to eq(in_range.id.to_s)
    end

    it "filters offers by lastSeenAt range" do
      in_range = create(:job_offer, last_seen_at: 1.day.ago)
      create(:job_offer, last_seen_at: 20.days.ago)

      query = <<~GRAPHQL
        query JobOffers($page: Int!, $perPage: Int!, $lastSeenAfter: ISO8601DateTime, $lastSeenBefore: ISO8601DateTime) {
          jobOffers(page: $page, perPage: $perPage, lastSeenAfter: $lastSeenAfter, lastSeenBefore: $lastSeenBefore) {
            totalCount
            nodes {
              id
            }
          }
        }
      GRAPHQL

      result = post_graphql(
        query: query,
        variables: {
          page: 1,
          perPage: 25,
          lastSeenAfter: 7.days.ago.iso8601,
          lastSeenBefore: Time.current.iso8601,
        }
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "jobOffers", "totalCount")).to eq(1)
      expect(result.dig("data", "jobOffers", "nodes").first["id"]).to eq(in_range.id.to_s)
    end

    it "sorts offers by score in descending order" do
      low = create(:job_offer, :with_score, value: 10, last_seen_at: 2.days.ago)
      high = create(:job_offer, :with_score, value: 90, last_seen_at: 1.day.ago)

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
          sortDirection: "desc",
        }
      )

      expect(result["errors"]).to be_nil
      node_ids = result.dig("data", "jobOffers", "nodes").map { |node| node["id"] }
      expect(node_ids.index(high.id.to_s)).to be < node_ids.index(low.id.to_s)
    end

    it "serializes on-site location mode as ON_SITE" do
      offer = create(:job_offer, :on_site)

      query = <<~GRAPHQL
        query JobOffers($page: Int!, $perPage: Int!) {
          jobOffers(page: $page, perPage: $perPage) {
            nodes {
              id
              locationMode
            }
          }
        }
      GRAPHQL

      result = post_graphql(query: query, variables: { page: 1, perPage: 25 })

      expect(result["errors"]).to be_nil
      node = result.dig("data", "jobOffers", "nodes").find { |n| n["id"] == offer.id.to_s }
      expect(node).to be_present
      expect(node["locationMode"]).to eq("ON_SITE")
    end

    it "excludes rejected offers by default" do
      visible_offer = create(:job_offer)
      create(:job_offer, :rejected)

      query = <<~GRAPHQL
        query JobOffers($page: Int!, $perPage: Int!) {
          jobOffers(page: $page, perPage: $perPage) {
            totalCount
            nodes {
              id
            }
          }
        }
      GRAPHQL

      result = post_graphql(query: query, variables: { page: 1, perPage: 25 })

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "jobOffers", "totalCount")).to eq(1)
      expect(result.dig("data", "jobOffers", "nodes").map { |n| n["id"] }).to eq([visible_offer.id.to_s])
    end

    it "excludes disabled offers by default" do
      visible_offer = create(:job_offer)
      create(:job_offer, :disabled)

      query = <<~GRAPHQL
        query JobOffers($page: Int!, $perPage: Int!) {
          jobOffers(page: $page, perPage: $perPage) {
            totalCount
            nodes {
              id
            }
          }
        }
      GRAPHQL

      result = post_graphql(query: query, variables: { page: 1, perPage: 25 })

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "jobOffers", "totalCount")).to eq(1)
      expect(result.dig("data", "jobOffers", "nodes").map { |n| n["id"] }).to eq([visible_offer.id.to_s])
    end
  end

  describe "query dashboardMetrics" do
    it "returns counts and source aggregates" do
      create(:job_offer, :with_score, value: 80,
        steps_details: {
          "fetch"  => { "at" => Time.current.iso8601, "version" => 1 },
          "enrich" => { "at" => Time.current.iso8601, "version" => 1 },
          "score"  => { "at" => Time.current.iso8601, "version" => 1 },
        })

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

  describe "steps_details field" do
    it "exposes typed step metadata on a job offer" do
      offer = create(:job_offer, steps_details: {
        "discovery" => { "at" => "2026-03-24T10:00:00Z", "version" => 1 },
        "fetch" => { "at" => "2026-03-24T10:30:00Z", "version" => 1 },
      })

      query = <<~GRAPHQL
        query JobOffer($id: ID!) {
          jobOffer(id: $id) {
            stepsDetails {
              discovery { at version }
              fetch { at version }
              analyze { at version }
            }
          }
        }
      GRAPHQL

      result = post_graphql(query: query, variables: { id: offer.id })

      expect(result["errors"]).to be_nil
      steps = result.dig("data", "jobOffer", "stepsDetails")
      expect(steps["discovery"]).to eq("at" => "2026-03-24T10:00:00Z", "version" => 1)
      expect(steps["fetch"]).to eq("at" => "2026-03-24T10:30:00Z", "version" => 1)
      expect(steps["analyze"]).to be_nil
    end

    it "returns nil for rejected offer on jobOffer query" do
      offer = create(:job_offer, :rejected)

      query = <<~GRAPHQL
        query JobOffer($id: ID!) {
          jobOffer(id: $id) {
            id
          }
        }
      GRAPHQL

      result = post_graphql(query: query, variables: { id: offer.id })

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "jobOffer")).to be_nil
    end
  end

  describe "mutation recomputeOfferScores" do
    it "enqueues one scoring job per offer" do
      first = create(:job_offer)
      second = create(:job_offer)

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
      expect(Sourcing::ScoringJob).to have_received(:perform_later).with(first.id)
      expect(Sourcing::ScoringJob).to have_received(:perform_later).with(second.id)
    end
  end

  describe "mutation launchDiscovery" do
    before do
      allow(Sourcing::LaunchDiscoveryJob).to receive(:perform_later)
    end

    it "enqueues launch discovery job without parameters" do
      mutation = <<~GRAPHQL
        mutation {
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

    it "enqueues launch discovery job with keywords parameter" do
      mutation = <<~GRAPHQL
        mutation LaunchDiscovery($keywords: [String!], $providers: [ProviderEnum!]) {
          launchDiscovery(input: { keywords: $keywords, providers: $providers }) {
            message
          }
        }
      GRAPHQL

      result = post_graphql(
        query: mutation,
        variables: {
          keywords: ["ruby", "rails"],
          providers: nil,
        }
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "launchDiscovery", "message")).to eq("Discovery job enqueued.")
      expect(Sourcing::LaunchDiscoveryJob).to have_received(:perform_later).with(keywords: ["ruby", "rails"], providers: nil, run_id: kind_of(Integer))
    end

    it "enqueues launch discovery job with providers parameter" do
      mutation = <<~GRAPHQL
        mutation LaunchDiscovery($keywords: [String!], $providers: [ProviderEnum!]) {
          launchDiscovery(input: { keywords: $keywords, providers: $providers }) {
            message
          }
        }
      GRAPHQL

      result = post_graphql(
        query: mutation,
        variables: {
          keywords: nil,
          providers: ["linkedin", "indeed"],
        }
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "launchDiscovery", "message")).to eq("Discovery job enqueued.")
      expect(Sourcing::LaunchDiscoveryJob).to have_received(:perform_later).with(keywords: nil, providers: ["linkedin", "indeed"], run_id: kind_of(Integer))
    end

    it "enqueues launch discovery job with both keywords and providers parameters" do
      mutation = <<~GRAPHQL
        mutation LaunchDiscovery($keywords: [String!], $providers: [ProviderEnum!]) {
          launchDiscovery(input: { keywords: $keywords, providers: $providers }) {
            message
          }
        }
      GRAPHQL

      result = post_graphql(
        query: mutation,
        variables: {
          keywords: ["ruby"],
          providers: ["linkedin", "indeed", "apec"],
        }
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "launchDiscovery", "message")).to eq("Discovery job enqueued.")
      expect(Sourcing::LaunchDiscoveryJob).to have_received(:perform_later).with(keywords: ["ruby"], providers: ["linkedin", "indeed", "apec"], run_id: kind_of(Integer))
    end
  end

  describe "query pipelineErrors" do
    let(:list_query) do
      <<~GRAPHQL
        query PipelineErrors(
          $page: Int!, $perPage: Int!, $resolved: Boolean,
          $steps: [String!], $sources: [String!], $errorClass: String, $runId: ID
        ) {
          pipelineErrors(
            page: $page, perPage: $perPage, resolved: $resolved,
            steps: $steps, sources: $sources, errorClass: $errorClass, runId: $runId
          ) {
            totalCount
            totalPages
            nodes { id step source errorClass errorMessage resolved jobOfferId runId }
          }
        }
      GRAPHQL
    end

    it "returns errors with filters applied" do
      offer = create(:job_offer, source: "linkedin")
      target = PipelineError.create!(
        job_offer_id: offer.id, step: "fetch", source: "linkedin",
        error_class: "RuntimeError", error_message: "boom", resolved: false
      )
      PipelineError.create!(
        step: "analyze", source: "wttj",
        error_class: "ArgumentError", error_message: "other", resolved: false
      )
      PipelineError.create!(
        step: "fetch", source: "linkedin",
        error_class: "RuntimeError", error_message: "already fixed", resolved: true
      )

      result = post_graphql(
        query: list_query,
        variables: { page: 1, perPage: 25, resolved: false, steps: ["fetch"], sources: ["linkedin"] }
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "pipelineErrors", "totalCount")).to eq(1)
      node = result.dig("data", "pipelineErrors", "nodes").first
      expect(node["id"]).to eq(target.id.to_s)
      expect(node["step"]).to eq("fetch")
      expect(node["source"]).to eq("linkedin")
      expect(node["errorClass"]).to eq("RuntimeError")
      expect(node["resolved"]).to eq(false)
      expect(node["jobOfferId"]).to eq(offer.id.to_s)
    end

    it "returns both resolved and unresolved when resolved filter is omitted" do
      PipelineError.create!(step: "fetch", error_class: "E", error_message: "a", resolved: true)
      PipelineError.create!(step: "fetch", error_class: "E", error_message: "b", resolved: false)

      result = post_graphql(
        query: list_query,
        variables: { page: 1, perPage: 25 }
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "pipelineErrors", "totalCount")).to eq(2)
    end

    it "exposes distinct error classes and sources via facet queries" do
      PipelineError.create!(step: "fetch", source: "linkedin", error_class: "RuntimeError", error_message: "x")
      PipelineError.create!(step: "fetch", source: "wttj", error_class: "ArgumentError", error_message: "y")
      PipelineError.create!(step: "fetch", source: nil, error_class: "RuntimeError", error_message: "z")

      result = post_graphql(
        query: "{ pipelineErrorClasses pipelineErrorSources }"
      )

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "pipelineErrorClasses")).to match_array(["ArgumentError", "RuntimeError"])
      expect(result.dig("data", "pipelineErrorSources")).to match_array(["linkedin", "wttj"])
    end
  end

  describe "query runs errorCount" do
    it "returns unresolved error counts batched in a single SQL query" do
      run_a = Run.create!
      run_b = Run.create!
      run_c = Run.create!

      2.times do |i|
        PipelineError.create!(run_id: run_a.id, step: "discovery", error_class: "E", error_message: "a#{i}", resolved: false)
      end
      PipelineError.create!(run_id: run_a.id, step: "discovery", error_class: "E", error_message: "resolved", resolved: true)
      PipelineError.create!(run_id: run_b.id, step: "discovery", error_class: "E", error_message: "b", resolved: false)
      # run_c has no errors

      count_queries = []
      callback = lambda do |_, _, _, _, payload|
        sql = payload[:sql]
        count_queries << sql if sql.include?("pipeline_errors") && sql.include?("COUNT")
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        result = post_graphql(query: "{ runs { id errorCount } }")
        expect(result["errors"]).to be_nil
        nodes = result.dig("data", "runs").index_by { |n| n["id"] }
        expect(nodes[run_a.id.to_s]["errorCount"]).to eq(2)
        expect(nodes[run_b.id.to_s]["errorCount"]).to eq(1)
        expect(nodes[run_c.id.to_s]["errorCount"]).to eq(0)
      end

      expect(count_queries.size).to eq(1), "expected a single batched COUNT query, got #{count_queries.size}: #{count_queries.inspect}"
    end
  end
end
