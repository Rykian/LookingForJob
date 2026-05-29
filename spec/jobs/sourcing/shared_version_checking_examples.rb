# Shared example for jobs that delegate to Sourcing::Pipeline for skip/advance.
#
# Consumers must provide (in their describe/context, NOT inside the shared
# block — definitions inside `it_behaves_like` are evaluated in a nested
# example group that shadows the parent):
#
#   let(:step_name)         { "fetch" }
#   let(:current_version)   { 1 }
#   let(:extra_offer_attrs) { {} }          # merged into JobOffer.create!
#   def prepare_offer(offer); end           # post-create hook (e.g. attach html)
#   def stub_step_not_to_be_called          # asserts the step is not called
#   def stub_step_to_be_called_once         # stubs the step to return success
#
# The two stub_step_* hooks let consumers pick instance-method
# (allow_any_instance_of(...)) vs class-method (allow(SomeStep).to receive(...))
# stubbing without coupling the shared example to one approach.
RSpec.shared_examples "skippable sourcing job with version checking" do
  before { allow(Sourcing::Pipeline).to receive(:advance) }

  it "skips step and asks Pipeline to advance when version matches and force is false" do
    offer = build_versioned_offer("skip")
    stub_step_not_to_be_called

    described_class.perform_now(offer.id, force: false)

    expect(Sourcing::Pipeline).to have_received(:advance).with(
      satisfy { |o| o.id == offer.id },
      step_name,
      nil,
      force: false
    )
  end

  it "runs step and asks Pipeline to advance with force when force is true" do
    offer = build_versioned_offer("force")
    stub_step_to_be_called_once

    described_class.perform_now(offer.id, force: true)

    expect(Sourcing::Pipeline).to have_received(:advance).with(
      satisfy { |o| o.id == offer.id },
      step_name,
      nil,
      force: true
    )
  end

  def build_versioned_offer(suffix)
    offer = JobOffer.create!({
      source: "linkedin",
      url: "https://example.com/jobs/#{step_name}-#{suffix}",
      url_hash: Digest::SHA256.hexdigest("https://example.com/jobs/#{step_name}-#{suffix}"),
      last_seen_at: Time.zone.parse("2026-03-20 10:00:00"),
      steps_details: {
        step_name => { "version" => current_version, "at" => Time.current.iso8601 },
      },
    }.merge(extra_offer_attrs))
    prepare_offer(offer)
    offer
  end
end
