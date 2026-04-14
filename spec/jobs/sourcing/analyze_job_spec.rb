require "rails_helper"
require_relative "shared_version_checking_examples"

class MockAnalyzeStep
  VERSION = 1
  PERSISTED_ATTRIBUTES = %i[
    title
    company
    employment_type
    description_html
    salary_min_minor
    salary_max_minor
    salary_currency
    posted_at
  ].freeze

  def call(source:, url:, url_hash:, html_content:)
    {
      title: "Backend Engineer",
      company: "Acme",
      location_mode: "hybrid",
      employment_type: "PERMANENT",
      description_html: "<p>desc</p>",
      salary_min_minor: 60000,
      salary_max_minor: 80000,
      salary_currency: "EUR",
      posted_at: Time.zone.parse("2026-03-20 09:00:00"),
      city: "Nantes",
    }
  end
end

RSpec.describe Sourcing::AnalyzeJob, type: :job do
  include ActiveJob::TestHelper

  let(:analyze_step) { MockAnalyzeStep.new }
  let(:registry) { Sourcing::ProviderRegistry.new }

  before do
    registry.register(
      "linkedin",
      Sourcing::Provider.new(
        discovery_step: nil,
        fetch_step: nil,
        analyze_step: analyze_step,
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

  it "stores extracted fields and enqueues enrich job" do
    offer = JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/123",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/123"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00")
    )
    offer.html_file.attach(
      io: StringIO.new("<html>content</html>"),
      filename: "html_content.html",
      content_type: "text/html"
    )

    described_class.perform_now(offer.id)

    offer.reload
    expect(offer.title).to eq("Backend Engineer")
    expect(offer.city).to be_nil
    expect(offer.location_mode).to be_nil
    expect(offer.employment_type).to eq("permanent")
    expect(offer.employment_type_before_type_cast).to eq("PERMANENT")
    expect(offer.steps_details["analyze"]).to include("version" => 1)

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::EnrichJob }
    expect(queued.size).to eq(1)
    expect(queued.first[:args].first).to eq(offer.id)
  end

  it "returns when offer is missing or has no html" do
    expect { described_class.perform_now(-1) }.not_to raise_error

    offer = JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/no-html",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/no-html"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00")
    )

    expect { described_class.perform_now(offer.id) }.not_to raise_error
  end

  describe "version checking behavior" do
    let(:step_name) { "analyze" }
    let(:next_job_class) { Sourcing::EnrichJob }
    let(:mock_step_class) { MockAnalyzeStep }

    it_behaves_like "skippable sourcing job with version checking"
  end
end
