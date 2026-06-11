require "rails_helper"
require "active_job/continuation/test_helper"

RSpec.describe Sourcing::CanonicalizeTechnologiesJob, type: :job do
  include ActiveJob::Continuation::TestHelper

  # Hash-backed fake so set→get→del round-trips across continuation steps.
  let(:redis_store) { {} }
  let(:fake_redis) do
    store = redis_store
    Class.new do
      define_method(:set) { |key, value, **_opts| store[key] = value; "OK" }
      define_method(:get) { |key| store[key] }
      define_method(:del) { |key| store.delete(key) ? 1 : 0 }
    end.new
  end

  # Deterministic canonical mapping so no real LLM call is made.
  let(:alias_map) do
    {
      "node" => "Node.js",
      "nodejs" => "Node.js",
      "Aqua Security" => "Aqua Security",
    }
  end

  # Isolate the canonicalize_scoring_profile! step from the real
  # data/scoring_profile.json. Already-canonical content means that step no-ops
  # for the tests that don't care about it; the profile-rewrite test re-stubs
  # PROFILE_PATH with its own lowercase fixture.
  let(:profile_tmp) do
    tmp = Tempfile.new(["scoring_profile", ".json"])
    tmp.write(JSON.generate("technology" => { "primary" => ["Ruby"], "secondary" => [] }))
    tmp.flush
    tmp
  end

  after { profile_tmp.close! }

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

  before do
    allow(Sidekiq).to receive(:redis).and_yield(fake_redis)
    # Avoid LLM credential setup and the network entirely.
    llm_config = instance_double(Sourcing::LlmConfig, configure!: nil, model: "stub", provider: "stub")
    allow(Sourcing::LlmConfig).to receive(:from_env).and_return(llm_config)
    allow_any_instance_of(Sourcing::CanonicalizeTechnologiesService)
      .to receive(:batch_alias_map).and_return(alias_map)
    stub_const("Sourcing::ScoringProfile::PROFILE_PATH", profile_tmp.path)
    allow(Sourcing::ScoringProfile).to receive(:reload!)
  end

  def create_offer(url_suffix, primary:, secondary: [])
    JobOffer.create!(
      source: "linkedin",
      url: "https://example.com/jobs/#{url_suffix}",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/#{url_suffix}"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      primary_technologies: primary,
      secondary_technologies: secondary
    )
  end

  it "runs all continuation steps end-to-end and canonicalizes offers" do
    offer = create_offer("dedup-1", primary: ["node", " Aqua Security"], secondary: ["nodejs"])

    described_class.perform_now

    offer.reload
    expect(offer.primary_technologies).to eq(["Node.js", "Aqua Security"])
    expect(offer.secondary_technologies).to eq(["Node.js"])

    # Durable artifacts persisted to Redis, snapshot cleaned up.
    expect(JSON.parse(redis_store[Sourcing::TechnologyStore::ALIAS_MAP_KEY])).to eq(alias_map)
    expect(JSON.parse(redis_store[Sourcing::TechnologyStore::COMMON_KEY])).to include("Node.js")
    expect(redis_store).not_to have_key(described_class::SNAPSHOT_KEY)
  end

  it "checkpoints after build_alias_map and resumes without losing work" do
    offer = create_offer("dedup-resume", primary: ["node"], secondary: ["nodejs"])

    described_class.perform_later

    # Run until build_alias_map completes, then interrupt before any offer is rewritten.
    # The job re-enqueues itself (resume_options wait: 5s); the dup'd snapshot in
    # flush_enqueued_jobs means this first drain won't pick the resumed job up.
    interrupt_job_after_step(described_class, :build_alias_map) { perform_enqueued_jobs }

    # Checkpoint state: alias map persisted to Redis, snapshot still live (cleanup
    # not reached), offer untouched (apply_alias_map not run yet).
    expect(redis_store).to have_key(Sourcing::TechnologyStore::ALIAS_MAP_KEY)
    expect(redis_store).to have_key(described_class::SNAPSHOT_KEY)
    expect(offer.reload.primary_technologies).to eq(["node"])

    # Resume the re-enqueued continuation to completion.
    perform_enqueued_jobs

    offer.reload
    expect(offer.primary_technologies).to eq(["Node.js"])
    expect(offer.secondary_technologies).to eq(["Node.js"])
    expect(JSON.parse(redis_store[Sourcing::TechnologyStore::COMMON_KEY])).to include("Node.js")
    expect(redis_store).not_to have_key(described_class::SNAPSHOT_KEY)
  end

  it "canonicalizes the scoring profile's technology lists" do
    # An offer is required so raw_technologies is non-empty and the alias map
    # gets written to Redis (empty batch list → write never fires).
    create_offer("dedup-profile", primary: ["node"])

    profile_data = {
      "$schema" => "./scoring_profile.schema.json",
      "technology" => { "primary" => ["node"], "secondary" => ["nodejs"] },
      "location" => { "preference" => ["remote"] },
    }
    tmp = Tempfile.new(["scoring_profile", ".json"])
    tmp.write(JSON.generate(profile_data))
    tmp.flush

    stub_const("Sourcing::ScoringProfile::PROFILE_PATH", tmp.path)
    allow(Sourcing::ScoringProfile).to receive(:reload!)

    described_class.perform_now

    written = JSON.parse(File.read(tmp.path))
    expect(written.dig("technology", "primary")).to eq(["Node.js"])
    expect(written.dig("technology", "secondary")).to eq(["Node.js"])
  ensure
    tmp&.close!
  end

  it "leaves already-canonical offers unchanged (idempotent)" do
    offer = create_offer("dedup-2", primary: ["Node.js"], secondary: [])

    expect { described_class.perform_now }.not_to(change { offer.reload.updated_at })
    expect(offer.primary_technologies).to eq(["Node.js"])
  end
end
