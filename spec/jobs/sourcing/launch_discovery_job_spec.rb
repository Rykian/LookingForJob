require "rails_helper"

RSpec.describe Sourcing::LaunchDiscoveryJob, type: :job do
  include ActiveJob::TestHelper

  let(:work_mode_step) { instance_double(Sourcing::DiscoveryStep, supports_work_mode_filter?: true) }
  let(:no_work_mode_step) { instance_double(Sourcing::DiscoveryStep, supports_work_mode_filter?: false) }
  let(:registry) { Sourcing::ProviderRegistry.new }

  before do
    registry.register(
      "linkedin",
      Sourcing::Provider.new(
        discovery_step: work_mode_step,
        fetch_step: nil,
        analyze_step: nil,
        enrich_step: nil
      )
    )

    registry.register(
      "france_travail",
      Sourcing::Provider.new(
        discovery_step: no_work_mode_step,
        fetch_step: nil,
        analyze_step: nil,
        enrich_step: nil
      )
    )

    allow(Sourcing::Providers).to receive(:registry).and_return(registry)
    allow(ENV).to receive(:[]).and_call_original
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

  it "enqueues one job per work mode only for providers that support work mode filtering" do
    allow(ENV).to receive(:[]).with("KEYWORDS").and_return("ruby, rails ")
    allow(ENV).to receive(:[]).with("WORK_MODE").and_return("remote, hybrid")

    described_class.perform_now

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::DiscoveryJob }

    expect(queued.size).to eq(6)
    normalized_args = queued.map do |job|
      job[:args].first.deep_symbolize_keys.slice(:source, :keyword, :work_mode)
    end

    expect(normalized_args).to match_array([
      { source: "linkedin", keyword: "ruby", work_mode: "remote" },
      { source: "linkedin", keyword: "ruby", work_mode: "hybrid" },
      { source: "linkedin", keyword: "rails", work_mode: "remote" },
      { source: "linkedin", keyword: "rails", work_mode: "hybrid" },
      { source: "france_travail", keyword: "ruby", work_mode: "remote" },
      { source: "france_travail", keyword: "rails", work_mode: "remote" }
    ])
  end

  it "fails loudly when KEYWORDS is missing" do
    allow(ENV).to receive(:[]).with("KEYWORDS").and_return(nil)
    allow(ENV).to receive(:[]).with("WORK_MODE").and_return("remote")

    expect do
      described_class.perform_now
    end.to raise_error(ArgumentError, "Missing required environment variable: KEYWORDS")
  end

  it "fails loudly when WORK_MODE has no usable values" do
    allow(ENV).to receive(:[]).with("KEYWORDS").and_return("ruby")
    allow(ENV).to receive(:[]).with("WORK_MODE").and_return(", ,")

    expect do
      described_class.perform_now
    end.to raise_error(ArgumentError, "Environment variable WORK_MODE must contain at least one value")
  end
end
