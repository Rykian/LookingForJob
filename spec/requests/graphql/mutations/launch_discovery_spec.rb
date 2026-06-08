require "rails_helper"

RSpec.describe "GraphQL mutation launchDiscovery", type: :request do
  before do
    allow(Sourcing::LaunchDiscoveryJob).to receive(:perform_later)
  end

  it "enqueues launch discovery job" do
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
