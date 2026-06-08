require "rails_helper"

RSpec.describe "GraphQL query dashboardMetrics", type: :request do
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
