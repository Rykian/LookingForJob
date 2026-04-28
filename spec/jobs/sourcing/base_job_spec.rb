require "rails_helper"

RSpec.describe Sourcing::BaseJob, type: :job do
  SOURCING_JOB_CLASSES = [
    Sourcing::DiscoveryJob,
    Sourcing::FetchJob,
    Sourcing::AnalyzeJob,
    Sourcing::EnrichJob,
    Sourcing::ScoringJob,
    Sourcing::LaunchDiscoveryJob,
  ].freeze

  before do
    stub_const("Sourcing::BaseJobSpecJob", Class.new(Sourcing::BaseJob) do
      def perform(fail_job: false)
        raise "boom" if fail_job
      end
    end)
  end

  it "is inherited by all sourcing jobs in the pipeline" do
    expect(SOURCING_JOB_CLASSES).to all(satisfy { |klass| klass < described_class })
  end

  let(:redis) { instance_double("Redis") }
  let(:subscriptions) { instance_double("GraphQLSubscriptions", trigger: nil) }
  let(:status_payload) { { running: true, queued: 2 } }

  before do
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    allow(Sourcing::JobStatusService).to receive(:call).and_return(status_payload)
    allow(LookingForJobSchema).to receive(:subscriptions).and_return(subscriptions)
  end

  describe "around_perform" do
    it "runs perform, then broadcasts in ensure on success" do
      allow(redis).to receive(:set).and_return(true)
      events = []

      allow_any_instance_of(Sourcing::BaseJobSpecJob).to receive(:perform).and_wrap_original do |original, *args, **kwargs, &blk|
        events << :perform
        original.call(*args, **kwargs, &blk)
      end
      allow_any_instance_of(Sourcing::BaseJobSpecJob).to receive(:broadcast_sourcing_status).and_wrap_original do |original, *args, **kwargs, &blk|
        events << :broadcast
        original.call(*args, **kwargs, &blk)
      end

      Sourcing::BaseJobSpecJob.perform_now

      expect(events).to eq([:perform, :broadcast])
    end

    it "runs perform, then broadcasts in ensure when perform raises" do
      allow(redis).to receive(:set).and_return(true)
      events = []

      allow_any_instance_of(Sourcing::BaseJobSpecJob).to receive(:perform).and_wrap_original do |original, *args, **kwargs, &blk|
        events << :perform
        original.call(*args, **kwargs, &blk)
      end
      allow_any_instance_of(Sourcing::BaseJobSpecJob).to receive(:broadcast_sourcing_status).and_wrap_original do |original, *args, **kwargs, &blk|
        events << :broadcast
        original.call(*args, **kwargs, &blk)
      end

      expect do
        Sourcing::BaseJobSpecJob.perform_now(fail_job: true)
      end.to raise_error(RuntimeError, "boom")

      expect(events).to eq([:perform, :broadcast])
    end
  end

  it "broadcasts sourcing status when throttle lock is acquired" do
    allow(redis).to receive(:set).and_return("OK")

    Sourcing::BaseJobSpecJob.perform_now

    expect(Sourcing::JobStatusService).to have_received(:call).once
    expect(subscriptions).to have_received(:trigger).with(:sourcing_status, {}, status_payload)
  end

  it "uses redis nx+ex lock with expected key and ttl for throttle" do
    allow(redis).to receive(:set).and_return("OK")

    Sourcing::BaseJobSpecJob.perform_now

    expect(redis).to have_received(:set).with(
      Sourcing::BaseJob::STATUS_TRIGGER_LOCK_KEY,
      kind_of(String),
      nx: true,
      ex: Sourcing::BaseJob::STATUS_TRIGGER_THROTTLE_SECONDS
    )
  end

  it "skips broadcast when throttle lock is not acquired" do
    allow(redis).to receive(:set).and_return(nil)

    Sourcing::BaseJobSpecJob.perform_now

    expect(Sourcing::JobStatusService).not_to have_received(:call)
    expect(subscriptions).not_to have_received(:trigger)
  end

  it "falls back to broadcasting when redis throttle check fails" do
    allow(Sidekiq).to receive(:redis).and_raise(StandardError.new("redis unavailable"))
    allow(Rails.logger).to receive(:warn)

    Sourcing::BaseJobSpecJob.perform_now

    expect(Rails.logger).to have_received(:warn).with(/sourcing_status throttle check failed/)
    expect(Sourcing::JobStatusService).to have_received(:call).once
    expect(subscriptions).to have_received(:trigger).with(:sourcing_status, {}, status_payload)
  end

  it "still runs status broadcast when the job perform method raises" do
    allow(redis).to receive(:set).and_return(true)

    expect do
      Sourcing::BaseJobSpecJob.perform_now(fail_job: true)
    end.to raise_error(RuntimeError, "boom")

    expect(Sourcing::JobStatusService).to have_received(:call).once
    expect(subscriptions).to have_received(:trigger).with(:sourcing_status, {}, status_payload)
  end

  it "swallows trigger failures and logs a warning" do
    allow(redis).to receive(:set).and_return(true)
    allow(subscriptions).to receive(:trigger).and_raise(StandardError.new("trigger error"))
    allow(Rails.logger).to receive(:warn)

    expect { Sourcing::BaseJobSpecJob.perform_now }.not_to raise_error

    expect(Rails.logger).to have_received(:warn).with(/sourcing_status trigger failed/)
  end
end
