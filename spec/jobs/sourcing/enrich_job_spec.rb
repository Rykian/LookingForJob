require "rails_helper"

RSpec.describe Sourcing::EnrichJob, type: :job do
  it "stores enrichment fields and enriched_at" do
    offer = JobOffer.create!(
      source: "linkedin",
      keyword: "ruby",
      work_mode: "remote",
      url: "https://example.com/jobs/123",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/123"),
      first_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      html_content: "<html>content</html>",
      fetched_at: Time.current,
      title: "Backend Engineer",
      company: "Acme"
    )

    enrichment = {
      hybrid_remote_days_min_per_week: 3,
      primary_technologies: ["Ruby on Rails"],
      secondary_technologies: ["Redis"],
      offer_language: "en",
      normalized_seniority: "senior",
      english_level_required: "professional"
    }

    allow_any_instance_of(Sourcing::EnrichStep).to receive(:call).and_return(enrichment)

    described_class.perform_now(url_hash: offer.url_hash)

    offer.reload
    expect(offer.hybrid_remote_days_min_per_week).to eq(3)
    expect(offer.primary_technologies).to eq(["Ruby on Rails"])
    expect(offer.normalized_seniority).to eq("senior")
    expect(offer.enriched_at).not_to be_nil
  end

  it "returns when offer is missing or has no html" do
    expect { described_class.perform_now(url_hash: "missing") }.not_to raise_error
  end
end
