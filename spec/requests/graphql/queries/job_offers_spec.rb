require "rails_helper"

RSpec.describe "GraphQL query jobOffers", type: :request do
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

  it "filters offers by language and max level" do
    no_requirement = create(:job_offer, languages: [])
    basic = create(:job_offer, languages: [{ "language" => "en", "level" => "basic" }])
    fluent = create(:job_offer, languages: [
      { "language" => "en", "level" => "fluent" },
      { "language" => "fr", "level" => "not_required" },
    ])

    query = <<~GRAPHQL
      query JobOffers($page: Int!, $perPage: Int!, $language: String, $maxLanguageLevel: LanguageLevelEnum) {
        jobOffers(page: $page, perPage: $perPage, language: $language, maxLanguageLevel: $maxLanguageLevel) {
          nodes {
            id
            languages {
              language
              level
            }
          }
        }
      }
    GRAPHQL

    result = post_graphql(
      query: query,
      variables: { page: 1, perPage: 25, language: "en", maxLanguageLevel: "BASIC" }
    )

    expect(result["errors"]).to be_nil
    ids = result.dig("data", "jobOffers", "nodes").map { |n| n["id"] }
    expect(ids).to contain_exactly(no_requirement.id.to_s, basic.id.to_s)

    result = post_graphql(
      query: query,
      variables: { page: 1, perPage: 25, language: "en", maxLanguageLevel: "FLUENT" }
    )

    nodes = result.dig("data", "jobOffers", "nodes")
    expect(nodes.map { |n| n["id"] }).to contain_exactly(no_requirement.id.to_s, basic.id.to_s, fluent.id.to_s)
    fluent_node = nodes.find { |n| n["id"] == fluent.id.to_s }
    expect(fluent_node["languages"]).to contain_exactly(
      { "language" => "en", "level" => "FLUENT" },
      { "language" => "fr", "level" => "NOT_REQUIRED" }
    )
  end

  it "lists known language codes" do
    create(:job_offer, languages: [{ "language" => "de", "level" => "professional" }])

    result = post_graphql(query: "{ jobOfferLanguageCodes }")

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "jobOfferLanguageCodes")).to include("de")
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

  it "filters offers to the ids returned by a Meilisearch search" do
    matching = create(:job_offer, title: "Senior Rails Engineer")
    create(:job_offer, title: "Frontend Developer")

    index = stub_meilisearch([{ "id" => matching.id.to_s }])

    query = <<~GRAPHQL
      query JobOffers($page: Int!, $perPage: Int!, $search: String) {
        jobOffers(page: $page, perPage: $perPage, search: $search) {
          totalCount
          nodes {
            id
          }
        }
      }
    GRAPHQL

    result = post_graphql(query: query, variables: { page: 1, perPage: 25, search: "rails" })

    expect(index).to have_received(:search).with("rails", anything)
    expect(result["errors"]).to be_nil
    expect(result.dig("data", "jobOffers", "totalCount")).to eq(1)
    expect(result.dig("data", "jobOffers", "nodes").map { |n| n["id"] }).to eq([matching.id.to_s])
  end

  it "returns no offers when Meilisearch finds no matches" do
    create(:job_offer)
    stub_meilisearch([])

    query = <<~GRAPHQL
      query JobOffers($page: Int!, $perPage: Int!, $search: String) {
        jobOffers(page: $page, perPage: $perPage, search: $search) {
          totalCount
          nodes {
            id
          }
        }
      }
    GRAPHQL

    result = post_graphql(query: query, variables: { page: 1, perPage: 25, search: "zzz-no-match" })

    expect(result["errors"]).to be_nil
    expect(result.dig("data", "jobOffers", "totalCount")).to eq(0)
    expect(result.dig("data", "jobOffers", "nodes")).to be_empty
  end

  it "does not query Meilisearch when no search term is given" do
    visible_offer = create(:job_offer)
    expect(MeiliSearch::Rails).not_to receive(:client)

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
