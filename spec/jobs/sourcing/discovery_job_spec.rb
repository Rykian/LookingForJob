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

  it "upserts discovered urls and enqueues fetch jobs" do
    result = {
      discovered_urls: ["https://example.com/jobs/1", "https://example.com/jobs/2"],
      next_job_data: nil,
      has_next_page: false
    }

    allow(discovery_step).to receive(:call).and_return(result)

    expect do
      described_class.perform_now(
        source: "linkedin",
        keyword: "ruby",
        work_mode: "remote",
        page: 1
      )
    end.to change(JobOffer, :count).by(2)

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::FetchJob }
    expect(queued.size).to eq(2)
  end

  it "enqueues next discovery job when next page is available" do
    result = {
      discovered_urls: ["https://example.com/jobs/1"],
      next_job_data: {
        source: "linkedin",
        keyword: "ruby",
        work_mode: "remote",
        page: 2
      },
      has_next_page: true
    }

    allow(discovery_step).to receive(:call).and_return(result)

    described_class.perform_now(
      source: "linkedin",
      keyword: "ruby",
      work_mode: "remote",
      page: 1
    )

    next_discovery_jobs = enqueued_jobs.select { |job| job[:job] == described_class }
    expect(next_discovery_jobs.size).to eq(1)
  end
end
