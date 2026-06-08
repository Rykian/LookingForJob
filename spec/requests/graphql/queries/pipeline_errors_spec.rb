require "rails_helper"

RSpec.describe "GraphQL query pipelineErrors", type: :request do
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
