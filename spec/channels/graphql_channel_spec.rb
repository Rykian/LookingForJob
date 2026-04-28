require "rails_helper"

RSpec.describe GraphqlChannel, type: :channel do
  let(:initial_status) do
    {
      active: false,
      queued_count: 0,
      running_count: 0,
      updated_at: Time.current.iso8601,
    }
  end

  let(:triggered_status) do
    {
      active: true,
      queued_count: 7,
      running_count: 1,
      updated_at: Time.current.iso8601,
    }
  end

  let(:query) do
    <<~GRAPHQL
      subscription SourcingStatus {
        sourcingStatus {
          active
          queuedCount
          runningCount
          updatedAt
        }
      }
    GRAPHQL
  end

  it "registers subscription and relays pushed updates" do
    allow(Sourcing::JobStatusService).to receive(:call).and_return(initial_status)
    allow(ActionCable.server).to receive(:broadcast).and_call_original

    subscribe

    perform :execute, { "query" => query, "variables" => {}, "operationName" => "SourcingStatus" }

    expect(transmissions.last.dig("result", "data", "sourcingStatus", "queuedCount")).to eq(0)
    expect(transmissions.last["more"]).to eq(true)

    LookingForJobSchema.subscriptions.trigger(:sourcing_status, {}, triggered_status)

    expect(ActionCable.server).to have_received(:broadcast).with("graphql-event::sourcingStatus:", anything)
  end
end
