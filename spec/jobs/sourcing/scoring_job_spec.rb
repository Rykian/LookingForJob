require "rails_helper"

RSpec.describe Sourcing::ScoringJob, type: :job do
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
        hybrid: { allowed_cities: ["Nantes"] }
      }
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
end
