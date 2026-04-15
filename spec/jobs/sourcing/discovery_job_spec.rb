require "rails_helper"

class MockDiscoveryStep
  VERSION = 1

  def initialize_playwright(input:)
    { mode: :crawler }
  end

  def crawl_page(input:, playwright_runtime:, page:)
    { discovered_urls: [], has_next_page: false }
  end

  def close_playwright(playwright_runtime:)
  end
end

RSpec.describe Sourcing::DiscoveryJob, type: :job do
  include ActiveJob::TestHelper

  let(:discovery_step) { MockDiscoveryStep.new }
  let(:registry) { Sourcing::ProviderRegistry.new }

  before do
    registry.register(
      "linkedin",
      Sourcing::Provider.new(
        discovery_step: discovery_step,
        fetch_step: nil,
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

  it "upserts all discovered urls and enqueues fetch jobs" do
    result = {
      discovered_urls: ["https://example.com/jobs/1", "https://example.com/jobs/2"],
      has_next_page: false,
    }
    runtime = { mode: :crawler }

    allow_any_instance_of(MockDiscoveryStep).to receive(:initialize_playwright).and_return(runtime)
    allow_any_instance_of(MockDiscoveryStep).to receive(:crawl_page).and_return(result)
    allow_any_instance_of(MockDiscoveryStep).to receive(:close_playwright)

    expect do
      described_class.perform_now(
        source: "linkedin",
        keyword: "ruby",
        work_mode: "remote"
      )
    end.to change(JobOffer, :count).by(2)

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::FetchJob }
    expect(queued.size).to eq(2)

    offer = JobOffer.find_by(url: "https://example.com/jobs/1")
    expect(queued.map { |job| job[:args].first }).to include(offer.id)
    expect(queued.first[:args].second).to include("force" => false)
    expect(offer.steps_details["discovery"]).to include("version" => 1)
    expect(offer.steps_details.dig("discovery", "at")).to match(/\A\d{4}-\d{2}-\d{2}T/)
    expect(offer.keywords).to eq(["ruby"])
  end

  it "propagates force to the fetch job through the event subscriber" do
    runtime = { mode: :crawler }
    allow_any_instance_of(MockDiscoveryStep).to receive(:initialize_playwright).and_return(runtime)
    allow_any_instance_of(MockDiscoveryStep).to receive(:crawl_page).and_return(
      { discovered_urls: ["https://example.com/jobs/force"], has_next_page: false }
    )
    allow_any_instance_of(MockDiscoveryStep).to receive(:close_playwright)

    described_class.perform_now(
      source: "linkedin",
      keyword: "ruby",
      work_mode: "remote",
      force: true
    )

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::FetchJob }
    expect(queued.size).to eq(1)
    expect(queued.first[:args].second).to include("force" => true)
  end

  it "does not enqueue further discovery jobs (pagination is internal to the step)" do
    runtime = { mode: :crawler }
    allow_any_instance_of(MockDiscoveryStep).to receive(:initialize_playwright).and_return(runtime)
    allow_any_instance_of(MockDiscoveryStep).to receive(:crawl_page).and_return({ discovered_urls: [], has_next_page: false })
    allow_any_instance_of(MockDiscoveryStep).to receive(:close_playwright)

    described_class.perform_now(
      source: "linkedin",
      keyword: "ruby",
      work_mode: "remote"
    )

    next_discovery_jobs = enqueued_jobs.select { |job| job[:job] == described_class }
    expect(next_discovery_jobs).to be_empty
  end

  it "uses page number as cursor while crawling" do
    runtime = { mode: :crawler }
    allow_any_instance_of(MockDiscoveryStep).to receive(:initialize_playwright).and_return(runtime)
    allow_any_instance_of(MockDiscoveryStep).to receive(:close_playwright)

    page_calls = []
    allow_any_instance_of(MockDiscoveryStep).to receive(:crawl_page) do |input: nil, playwright_runtime: nil, page: nil|
      page_calls << page
      if page == 1
        { discovered_urls: ["https://example.com/jobs/1"], has_next_page: true }
      else
        { discovered_urls: ["https://example.com/jobs/2"], has_next_page: false }
      end
    end

    described_class.perform_now(source: "linkedin", keyword: "ruby", work_mode: "remote")

    expect(page_calls).to eq([1, 2])
  end
end
