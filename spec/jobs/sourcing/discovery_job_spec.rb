require "rails_helper"

RSpec.describe Sourcing::DiscoveryJob, type: :job do
  include ActiveJob::TestHelper

  let(:discovery_step) { instance_double(Sourcing::DiscoveryStep) }
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
      discovered_urls: [ "https://example.com/jobs/1", "https://example.com/jobs/2" ],
      has_next_page: false
    }
    runtime = { mode: :crawler }

    allow(discovery_step).to receive(:initialize_playwright).and_return(runtime)
    allow(discovery_step).to receive(:crawl_page).and_return(result)
    allow(discovery_step).to receive(:close_playwright)

    expect do
      described_class.perform_now(
        source: "linkedin",
        keyword: "ruby",
        work_mode: "remote"
      )
    end.to change(JobOffer, :count).by(2)

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::FetchJob }
    expect(queued.size).to eq(2)
    expect(discovery_step).to have_received(:close_playwright).with(playwright_runtime: runtime)

    offer = JobOffer.find_by(url: "https://example.com/jobs/1")
    expect(offer.steps_details["discovery"]).to include("version" => 1)
    expect(offer.steps_details.dig("discovery", "at")).to match(/\A\d{4}-\d{2}-\d{2}T/)
  end

  it "does not enqueue further discovery jobs (pagination is internal to the step)" do
    runtime = { mode: :crawler }
    allow(discovery_step).to receive(:initialize_playwright).and_return(runtime)
    allow(discovery_step).to receive(:crawl_page).and_return({ discovered_urls: [], has_next_page: false })
    allow(discovery_step).to receive(:close_playwright)

    described_class.perform_now(
      source: "linkedin",
      keyword: "ruby",
      work_mode: "remote"
    )

    next_discovery_jobs = enqueued_jobs.select { |job| job[:job] == described_class }
    expect(next_discovery_jobs).to be_empty
    expect(discovery_step).to have_received(:close_playwright).with(playwright_runtime: runtime)
  end

  it "uses page number as cursor while crawling" do
    runtime = { mode: :crawler }
    allow(discovery_step).to receive(:initialize_playwright).and_return(runtime)
    allow(discovery_step).to receive(:close_playwright)

    allow(discovery_step).to receive(:crawl_page)
      .with(input: { source: "linkedin", keyword: "ruby", work_mode: "remote" }, playwright_runtime: runtime, page: 1)
      .and_return({ discovered_urls: [ "https://example.com/jobs/1" ], has_next_page: true })

    allow(discovery_step).to receive(:crawl_page)
      .with(input: { source: "linkedin", keyword: "ruby", work_mode: "remote" }, playwright_runtime: runtime, page: 2)
      .and_return({ discovered_urls: [ "https://example.com/jobs/2" ], has_next_page: false })

    described_class.perform_now(source: "linkedin", keyword: "ruby", work_mode: "remote")

    expect(discovery_step).to have_received(:crawl_page)
      .with(input: { source: "linkedin", keyword: "ruby", work_mode: "remote" }, playwright_runtime: runtime, page: 1)
      .once
    expect(discovery_step).to have_received(:crawl_page)
      .with(input: { source: "linkedin", keyword: "ruby", work_mode: "remote" }, playwright_runtime: runtime, page: 2)
      .once
  end
end
