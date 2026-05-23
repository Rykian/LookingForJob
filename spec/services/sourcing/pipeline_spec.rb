require "rails_helper"

class MockPipelineFetchStep
  VERSION = 1
end

class MockPipelineAnalyzeStep
  VERSION = 1
end

class MockPipelineEnrichStep
  VERSION = 1
end

class MockPipelineScoreStep
  VERSION = 2
end

RSpec.describe Sourcing::Pipeline do
  include ActiveJob::TestHelper

  let(:registry) { Sourcing::ProviderRegistry.new }

  before do
    registry.register(
      "linkedin",
      Sourcing::Provider.new(
        discovery_step: nil,
        fetch_step: MockPipelineFetchStep.new,
        analyze_step: MockPipelineAnalyzeStep.new,
        enrich_step: MockPipelineEnrichStep.new
      )
    )
    allow(Sourcing::Providers).to receive(:registry).and_return(registry)
    stub_const("Sourcing::ScoreStep", MockPipelineScoreStep)
  end

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    example.run
    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  def build_offer(steps_details: {})
    JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/#{SecureRandom.hex(4)}",
      url_hash: Digest::SHA256.hexdigest(SecureRandom.hex(8)),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      steps_details: steps_details
    )
  end

  it "enqueues FetchJob when no step has run" do
    offer = build_offer

    expect(described_class.advance(offer)).to eq("fetch")

    queued = enqueued_jobs.select { |j| j[:job] == Sourcing::FetchJob }
    expect(queued.size).to eq(1)
    expect(queued.first[:args].first).to eq(offer.id)
    expect(queued.first[:args].second).to include("force" => false, "source" => "linkedin")
  end

  it "skips up-to-date steps and enqueues the first outdated one" do
    offer = build_offer(steps_details: {
      "fetch" => { "version" => 1, "at" => Time.current.iso8601 },
      "analyze" => { "version" => 1, "at" => Time.current.iso8601 },
    })

    expect(described_class.advance(offer)).to eq("enrich")

    queued = enqueued_jobs.select { |j| j[:job] == Sourcing::EnrichJob }
    expect(queued.size).to eq(1)
  end

  it "treats a stored version mismatch as outdated" do
    offer = build_offer(steps_details: {
      "fetch" => { "version" => 99, "at" => Time.current.iso8601 },
    })

    expect(described_class.advance(offer)).to eq("fetch")
  end

  it "enqueues nothing when every step is current" do
    offer = build_offer(steps_details: {
      "fetch" => { "version" => 1, "at" => Time.current.iso8601 },
      "analyze" => { "version" => 1, "at" => Time.current.iso8601 },
      "enrich" => { "version" => 1, "at" => Time.current.iso8601 },
      "score" => { "version" => 2, "at" => Time.current.iso8601 },
    })

    expect(described_class.advance(offer)).to be_nil
    expect(enqueued_jobs).to be_empty
  end

  it "forwards force to the enqueued job without changing step selection" do
    offer = build_offer(steps_details: {
      "fetch" => { "version" => 1, "at" => Time.current.iso8601 },
    })

    expect(described_class.advance(offer, force: true)).to eq("analyze")

    queued = enqueued_jobs.select { |j| j[:job] == Sourcing::AnalyzeJob }
    expect(queued.first[:args].second).to include("force" => true)
  end
end
