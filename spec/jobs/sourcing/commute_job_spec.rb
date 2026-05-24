require "rails_helper"
require_relative "shared_version_checking_examples"

RSpec.describe Sourcing::CommuteJob, type: :job do
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

  it "persists commute_city_id, canonical city, and step metadata, then advances" do
    allow(Sourcing::Pipeline).to receive(:advance)
    paris = Commute::City.create!(name: "Paris", normalized_name: "paris", latitude: 48.85, longitude: 2.35)

    offer = JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/commute-1",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/commute-1"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      city: "paris",
      location_mode: "hybrid"
    )

    allow(Sourcing::ScoringProfile).to receive(:load).and_return({ commute: { origin_city: "Nantes", max_minutes: 45, mode: "driving" } })
    allow(Sourcing::CommuteStep).to receive(:call).and_return(
      Sourcing::CommuteStep::Result.new(status: :ok, commute_city_id: paris.id, canonical_city: "Paris", duration_minutes: 240)
    )

    described_class.perform_now(offer.id)

    offer.reload
    expect(offer.commute_city_id).to eq(paris.id)
    expect(offer.city).to eq("Paris")
    expect(offer.steps_details["commute"]).to include("version" => Sourcing::CommuteStep::VERSION)
    expect(offer.steps_details.dig("commute", "at")).to match(/\A\d{4}-\d{2}-\d{2}T/)
    expect(Sourcing::Pipeline).to have_received(:advance).with(satisfy { |o| o.id == offer.id }, "commute", force: false)
  end

  it "does not overwrite city when CommuteStep returns no canonical city" do
    allow(Sourcing::Pipeline).to receive(:advance)

    offer = JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/commute-skip",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/commute-skip"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      city: "Paris",
      location_mode: "remote"
    )

    allow(Sourcing::ScoringProfile).to receive(:load).and_return({ commute: { origin_city: "Nantes", max_minutes: 45, mode: "driving" } })
    allow(Sourcing::CommuteStep).to receive(:call).and_return(
      Sourcing::CommuteStep::Result.new(status: :skipped, commute_city_id: nil, canonical_city: nil, duration_minutes: nil)
    )

    described_class.perform_now(offer.id)

    offer.reload
    expect(offer.city).to eq("Paris")
    expect(offer.commute_city_id).to be_nil
    expect(offer.steps_details["commute"]).to include("version" => Sourcing::CommuteStep::VERSION)
  end

  it "returns when offer is missing" do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end

  describe "version checking behavior" do
    let(:step_name) { "commute" }
    let(:current_version) { Sourcing::CommuteStep::VERSION }
    let(:extra_offer_attrs) { { city: "Paris", location_mode: "hybrid" } }

    def prepare_offer(_offer); end

    def stub_step_not_to_be_called
      expect(Sourcing::CommuteStep).not_to receive(:call)
    end

    def stub_step_to_be_called_once
      allow(Sourcing::ScoringProfile).to receive(:load).and_return({})
      expect(Sourcing::CommuteStep).to receive(:call).once.and_return(
        Sourcing::CommuteStep::Result.new(status: :skipped, commute_city_id: nil, canonical_city: nil, duration_minutes: nil)
      )
    end

    it_behaves_like "skippable sourcing job with version checking"
  end
end
