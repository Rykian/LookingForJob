require "rails_helper"

RSpec.describe "GraphQL query runs", type: :request do
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
