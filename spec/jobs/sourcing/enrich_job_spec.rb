require "rails_helper"

RSpec.describe Sourcing::EnrichJob, type: :job do
  include ActiveJob::TestHelper

  let(:enrich_step) { instance_double(Sourcing::EnrichStep) }
  let(:registry) { Sourcing::ProviderRegistry.new }

  before do
    registry.register(
      "linkedin",
      Sourcing::Provider.new(
        discovery_step: nil,
        fetch_step: nil,
        analyze_step: nil,
        enrich_step: enrich_step
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

  it "stores enrichment fields" do
    offer = JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/123",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/123"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      title: "Backend Engineer",
      company: "Acme"
    )
    offer.html_file.attach(
      io: StringIO.new("<html>content</html>"),
      filename: "html_content.html",
      content_type: "text/html"
    )

    enrichment = {
      hybrid_remote_days_min_per_week: 3,
      primary_technologies: [ "Ruby on Rails" ],
      secondary_technologies: [ "Redis" ],
      offer_language: "en",
      normalized_seniority: "senior",
      english_level_required: "professional"
    }

    allow(enrich_step).to receive(:call).and_return(enrichment)

    described_class.perform_now(url_hash: offer.url_hash)

    offer.reload
    expect(offer.hybrid_remote_days_min_per_week).to eq(3)
    expect(offer.primary_technologies).to eq([ "Ruby on Rails" ])
    expect(offer.normalized_seniority).to eq("senior")
    expect(offer.steps_details["enrich"]).to include("version" => 1)
    expect(offer.steps_details.dig("enrich", "at")).to match(/\A\d{4}-\d{2}-\d{2}T/)

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::ScoringJob }
    expect(queued.size).to eq(1)
  end

  it "returns when offer is missing or has no html" do
    expect { described_class.perform_now(url_hash: "missing") }.not_to raise_error
  end
end
