require "rails_helper"

RSpec.describe "GraphQL query jobOffer", type: :request do
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
