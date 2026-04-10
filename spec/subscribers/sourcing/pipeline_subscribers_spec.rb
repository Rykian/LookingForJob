require "rails_helper"

RSpec.describe "Sourcing pipeline subscribers" do
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

  {
    Sourcing::PipelineEvents::OFFER_DISCOVERED => Sourcing::FetchJob,
    Sourcing::PipelineEvents::OFFER_FETCHED => Sourcing::AnalyzeJob,
    Sourcing::PipelineEvents::OFFER_ANALYZED => Sourcing::EnrichJob,
    Sourcing::PipelineEvents::OFFER_ENRICHED => Sourcing::ScoringJob,
  }.each do |event_name, job_class|
    it "enqueues #{job_class.name} for #{event_name}" do
      offer = JobOffer.create!(
        source: "linkedin",
        url: "https://example.com/jobs/#{job_class.name.demodulize.underscore}",
        url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/#{job_class.name.demodulize.underscore}"),
        last_seen_at: Time.zone.parse("2026-03-20 10:00:00")
      )

      Sourcing::PipelineEvents.notify(event_name, offer_id: offer.id, force: true)

      queued = enqueued_jobs.select { |job| job[:job] == job_class }
      expect(queued.size).to eq(1)
      expect(queued.first[:args].first).to eq(offer.id)
      expect(queued.first[:args].second).to include("force" => true)
    end
  end
end
