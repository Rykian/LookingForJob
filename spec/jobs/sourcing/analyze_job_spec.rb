require "rails_helper"

RSpec.describe Sourcing::AnalyzeJob, type: :job do
  include ActiveJob::TestHelper

  let(:analyze_step) { instance_double(Sourcing::AnalyzeStep) }
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
      keyword: "ruby",
      work_mode: "remote",
      url: "https://example.com/jobs/123",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/123"),
      first_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      html_content: "<html>content</html>",
      fetched_at: Time.current
    )

    extracted = {
      title: "Backend Engineer",
      company: "Acme",
      remote: "hybrid",
      employment_type: "PERMANENT",
      description_html: "<p>desc</p>",
      salary_min_minor: 60000,
      salary_max_minor: 80000,
      salary_currency: "EUR",
      posted_at: Time.zone.parse("2026-03-20 09:00:00")
    }

    allow(analyze_step).to receive(:call).and_return(extracted)

    described_class.perform_now(url_hash: offer.url_hash)

    offer.reload
    expect(offer.title).to eq("Backend Engineer")
    expect(offer.employment_type).to eq("permanent")
    expect(offer.employment_type_before_type_cast).to eq("PERMANENT")

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::EnrichJob }
    expect(queued.size).to eq(1)
  end

  it "returns when offer is missing or has no html" do
    expect { described_class.perform_now(url_hash: "missing") }.not_to raise_error

    offer = JobOffer.create!(
      source: "linkedin",
      keyword: "ruby",
      work_mode: "remote",
      url: "https://example.com/jobs/no-html",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/no-html"),
      first_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00")
    )

    expect { described_class.perform_now(url_hash: offer.url_hash) }.not_to raise_error
  end
end
