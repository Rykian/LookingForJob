require "rails_helper"

RSpec.describe "GraphQL mutation recomputeOfferScores", type: :request do
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
