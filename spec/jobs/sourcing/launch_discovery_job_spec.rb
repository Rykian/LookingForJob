require "rails_helper"

RSpec.describe Sourcing::LaunchDiscoveryJob, type: :job do
  include ActiveJob::TestHelper

  let(:work_mode_step) { instance_double(Sourcing::DiscoveryStep, supports_work_mode_filter?: true) }
  let(:no_work_mode_step) { instance_double(Sourcing::DiscoveryStep, supports_work_mode_filter?: false) }
  let(:registry) { Sourcing::ProviderRegistry.new }
  let(:profile) do
    {
      technology: { primary: ["ruby", "nodejs"] },
      location: { preference: ["remote", "hybrid"] },
    }
  end

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
    allow(Sourcing::ScoringProfile).to receive(:load).and_return(profile)
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
      { source: "france_travail", keyword: "rails", work_mode: "remote" },
    ])
  end

  it "falls back to scoring profile when KEYWORDS and WORK_MODE are not set" do
    allow(ENV).to receive(:[]).with("KEYWORDS").and_return(nil)
    allow(ENV).to receive(:[]).with("WORK_MODE").and_return(nil)

    described_class.perform_now

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::DiscoveryJob }
    normalized_args = queued.map do |job|
      job[:args].first.deep_symbolize_keys.slice(:source, :keyword, :work_mode)
    end

    expect(normalized_args).to include(
      { source: "linkedin", keyword: "ruby", work_mode: "remote" },
      { source: "linkedin", keyword: "nodejs", work_mode: "hybrid" },
      { source: "france_travail", keyword: "ruby", work_mode: "remote" },
      { source: "france_travail", keyword: "nodejs", work_mode: "remote" }
    )
  end

  it "uses canonical on-site work mode from scoring profile" do
    allow(Sourcing::ScoringProfile).to receive(:load).and_return(
      {
        technology: { primary: ["ruby"] },
        location: { preference: ["on-site"] },
      }
    )
    allow(ENV).to receive(:[]).with("KEYWORDS").and_return(nil)
    allow(ENV).to receive(:[]).with("WORK_MODE").and_return(nil)

    described_class.perform_now

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::DiscoveryJob }
    normalized_args = queued.map do |job|
      job[:args].first.deep_symbolize_keys.slice(:source, :keyword, :work_mode)
    end

    expect(normalized_args).to include(
      { source: "linkedin", keyword: "ruby", work_mode: "on-site" },
      { source: "france_travail", keyword: "ruby", work_mode: "on-site" }
    )
  end

  it "fails loudly when WORK_MODE env override includes non-canonical on-site token" do
    allow(ENV).to receive(:[]).with("KEYWORDS").and_return("ruby")
    allow(ENV).to receive(:[]).with("WORK_MODE").and_return("onsite")

    expect do
      described_class.perform_now
    end.to raise_error(ArgumentError, "Unsupported work mode(s): onsite. Supported values: remote, hybrid, on-site")
  end

  it "fails loudly when KEYWORDS env override has no usable values" do
    allow(ENV).to receive(:[]).with("KEYWORDS").and_return(", ,")
    allow(ENV).to receive(:[]).with("WORK_MODE").and_return(nil)

    expect do
      described_class.perform_now
    end.to raise_error(ArgumentError, "Environment variable KEYWORDS must contain at least one value")
  end

  it "fails loudly when WORK_MODE has no usable values" do
    allow(ENV).to receive(:[]).with("KEYWORDS").and_return("ruby")
    allow(ENV).to receive(:[]).with("WORK_MODE").and_return(", ,")

    expect do
      described_class.perform_now
    end.to raise_error(ArgumentError, "Environment variable WORK_MODE must contain at least one value")
  end

  it "uses provided keywords when passed as parameter" do
    allow(ENV).to receive(:[]).with("KEYWORDS").and_return(nil)
    allow(ENV).to receive(:[]).with("WORK_MODE").and_return(nil)

    described_class.perform_now(keywords: ["elixir", "scala"])

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::DiscoveryJob }
    normalized_args = queued.map do |job|
      job[:args].first.deep_symbolize_keys.slice(:keyword)
    end

    # 2 keywords x (2 work modes for linkedin + 1 for france_travail) = 6 jobs
    expect(normalized_args.map { |a| a[:keyword] }).to match_array(["elixir", "scala", "elixir", "scala", "elixir", "scala"])
  end

  it "uses provided providers when passed as parameter" do
    allow(ENV).to receive(:[]).with("KEYWORDS").and_return(nil)
    allow(ENV).to receive(:[]).with("WORK_MODE").and_return(nil)

    described_class.perform_now(providers: ["linkedin"])

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::DiscoveryJob }
    normalized_args = queued.map do |job|
      job[:args].first.deep_symbolize_keys.slice(:source)
    end

    # Only linkedin should be used, with 2 keywords x 2 work modes = 4 jobs
    expect(normalized_args.map { |a| a[:source] }.uniq).to match_array(["linkedin"])
    expect(queued.count).to eq(4)
  end

  it "uses provided keywords and providers together" do
    allow(ENV).to receive(:[]).with("KEYWORDS").and_return(nil)
    allow(ENV).to receive(:[]).with("WORK_MODE").and_return(nil)

    described_class.perform_now(keywords: ["ruby"], providers: ["linkedin"])

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::DiscoveryJob }
    normalized_args = queued.map do |job|
      job[:args].first.deep_symbolize_keys.slice(:source, :keyword)
    end

    # 1 keyword x 2 work modes for linkedin = 2 jobs
    expect(normalized_args).to match_array([
      { source: "linkedin", keyword: "ruby" },
      { source: "linkedin", keyword: "ruby" },
    ])
  end
end
