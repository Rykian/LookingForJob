require "rails_helper"

RSpec.describe Sourcing::ScoringJob, type: :job do
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

  it "persists score, score_breakdown and steps_details score entry" do
    offer = JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/score-1",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/score-1"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00")
    )

    profile = {
      technology: { primary: ["ruby"], secondary: [] },
      remote_hybrid: {
        importance: "high",
        preferred_modes: ["yes", "hybrid"],
        hybrid: { allowed_cities: ["Nantes"] },
      },
    }

    allow(Sourcing::ScoringProfile).to receive(:load).and_return(profile)
    allow(Sourcing::ScoreStep).to receive(:call).and_return([72, { technology: { score: 80 }, remote_hybrid: { score: 64 } }])

    described_class.perform_now(url_hash: offer.url_hash)

    offer.reload
    expect(offer.score).to eq(72)
    expect(offer.score_breakdown).to eq({ "technology" => { "score" => 80 }, "remote_hybrid" => { "score" => 64 } })
    expect(offer.steps_details["score"]).to include("version" => 1)
    expect(offer.steps_details.dig("score", "at")).to match(/\A\d{4}-\d{2}-\d{2}T/)
  end

  it "returns when offer is missing" do
    expect { described_class.perform_now(url_hash: "missing") }.not_to raise_error
  end

  it "logs and raises when profile loading fails" do
    offer = JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/score-2",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/score-2"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00")
    )

    allow(Sourcing::ScoringProfile).to receive(:load).and_raise("bad profile")
    allow(Rails.logger).to receive(:error)

    expect { described_class.perform_now(url_hash: offer.url_hash) }.to raise_error(RuntimeError, /bad profile/)
    expect(Rails.logger).to have_received(:error).with(/ScoringJob failed/)
  end

  it "skips score step if version matches and force is false" do
    offer = JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/score-3",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/score-3"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      score: 85,
      steps_details: {
        "score" => {
          "version" => 1,
          "at" => Time.current.iso8601,
        },
      }
    )

    call_count = 0
    allow(Sourcing::ScoreStep).to receive(:call) do
      call_count += 1
      [90, {}]
    end

    described_class.perform_now(url_hash: offer.url_hash, force: false)

    expect(call_count).to eq(0)

    offer.reload
    expect(offer.score).to eq(85)
  end

  it "forces score step execution even if version matches when force is true" do
    offer = JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/score-4",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/score-4"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      score: 85,
      steps_details: {
        "score" => {
          "version" => 1,
          "at" => Time.current.iso8601,
        },
      }
    )

    profile = {
      technology: { primary: ["rust"], secondary: [] },
    }

    allow(Sourcing::ScoringProfile).to receive(:load).and_return(profile)
    allow(Sourcing::ScoreStep).to receive(:call).and_return([92, { technology: { score: 95 } }])

    described_class.perform_now(url_hash: offer.url_hash, force: true)

    offer.reload
    expect(offer.score).to eq(92)
  end
end
