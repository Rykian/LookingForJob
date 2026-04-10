require "rails_helper"
require_relative "shared_version_checking_examples"

class MockFetchStep
  VERSION = 1

  def call(source:, url:, url_hash:)
    "<html>ok</html>"
  end
end

class MockFetchStepError
  VERSION = 1

  def call(source:, url:, url_hash:)
    raise Sourcing::Providers::Linkedin::FetchContentError, "shell_html"
  end
end

RSpec.describe Sourcing::FetchJob, type: :job do
  include ActiveJob::TestHelper

  before do
    stub_const("Sourcing::Providers::Linkedin::FetchContentError", Class.new(StandardError))
  end

  let(:fetch_step) { MockFetchStep.new }

  let(:registry) { Sourcing::ProviderRegistry.new }

  before do
    registry.register(
      "linkedin",
      Sourcing::Provider.new(
        discovery_step: nil,
        fetch_step: fetch_step,
        analyze_step: nil,
        enrich_step: nil
      )
    )

    allow(Sourcing::Providers).to receive(:registry).and_return(registry)
  end

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    example.run
    clear_enqueued_jobs
    clear_performed_jobs
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  it "fetches html and stores it on the offer" do
    offer = JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/123",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/123"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00")
    )

    described_class.perform_now(offer.id)

    offer.reload
    expect(offer.html_file).to be_attached
    expect(offer.html_file.download).to eq("<html>ok</html>")
    expect(offer.steps_details["fetch"]).to include("version" => 1)
    expect(offer.steps_details.dig("fetch", "at")).to match(/\A\d{4}-\d{2}-\d{2}T/)

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::AnalyzeJob }
    expect(queued.size).to eq(1)
    expect(queued.first[:args].first).to eq(offer.id)
  end

  it "returns when offer is missing" do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end

  it "fails loudly and does not enqueue analyze when provider raises fetch content error" do
    error_registry = Sourcing::ProviderRegistry.new
    error_registry.register(
      "linkedin",
      Sourcing::Provider.new(
        discovery_step: nil,
        fetch_step: MockFetchStepError.new,
        analyze_step: nil,
        enrich_step: nil
      )
    )
    allow(Sourcing::Providers).to receive(:registry).and_return(error_registry)

    offer = JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/456",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/456"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00")
    )

    expect do
      described_class.perform_now(offer.id)
    end.to raise_error(Sourcing::Providers::Linkedin::FetchContentError, /shell_html/)

    offer.reload
    expect(offer.html_file).not_to be_attached

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::AnalyzeJob }
    expect(queued).to be_empty
  end

  describe "version checking behavior" do
    let(:step_name) { "fetch" }
    let(:next_job_class) { Sourcing::AnalyzeJob }
    let(:mock_step_class) { MockFetchStep }

    it_behaves_like "skippable sourcing job with version checking"
  end
end
