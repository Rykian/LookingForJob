require "rails_helper"

RSpec.describe Sourcing::FetchJob, type: :job do
  include ActiveJob::TestHelper

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
      keyword: "ruby",
      work_mode: "remote",
      url: "https://example.com/jobs/123",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/123"),
      first_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00")
    )

    allow_any_instance_of(Sourcing::FetchStep).to receive(:call).and_return("<html>ok</html>")

    described_class.perform_now(url_hash: offer.url_hash)

    offer.reload
    expect(offer.html_content).to eq("<html>ok</html>")
    expect(offer.fetched_at).not_to be_nil

    queued = enqueued_jobs.select { |job| job[:job] == Sourcing::AnalyzeJob }
    expect(queued.size).to eq(1)
  end

  it "returns when offer is missing" do
    expect { described_class.perform_now(url_hash: "missing") }.not_to raise_error
  end
end
