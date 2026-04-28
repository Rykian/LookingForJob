require "rails_helper"

RSpec.describe Sourcing::JobStatusService do
  describe ".call" do
    it "counts only sourcing jobs in queue and workers" do
      queue_job = double("queue_job", item: { "wrapped" => "Sourcing::FetchJob" })
      non_sourcing_queue_job = double("queue_job", item: { "wrapped" => "CleanupJob" })

      queue = Class.new do
        def initialize(items)
          @items = items
        end

        def count(&block)
          @items.count(&block)
        end
      end.new([queue_job, non_sourcing_queue_job])

      workers = [
        ["proc-1", "thread-1", { "payload" => { "wrapped" => "Sourcing::AnalyzeJob" } }],
        ["proc-1", "thread-2", { "payload" => { "wrapped" => "OtherJob" } }],
      ]

      allow(Sidekiq::Queue).to receive(:all).and_return([queue])
      allow(Sidekiq::Workers).to receive(:new).and_return(workers)

      status = described_class.call

      expect(status[:active]).to be(true)
      expect(status[:queued_count]).to eq(1)
      expect(status[:running_count]).to eq(1)
      expect(status[:updated_at]).to be_present
    end

    it "extracts sourcing class from activejob wrapper payloads" do
      queue_job = double(
        "queue_job",
        item: {
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "args" => [{ "job_class" => "Sourcing::EnrichJob" }],
        }
      )

      queue = Class.new do
        def initialize(items)
          @items = items
        end

        def count(&block)
          @items.count(&block)
        end
      end.new([queue_job])

      allow(Sidekiq::Queue).to receive(:all).and_return([queue])
      allow(Sidekiq::Workers).to receive(:new).and_return([])

      status = described_class.call

      expect(status[:active]).to be(true)
      expect(status[:queued_count]).to eq(1)
      expect(status[:running_count]).to eq(0)
    end

    it "returns idle status when sidekiq api fails" do
      allow(Sidekiq::Queue).to receive(:all).and_raise(StandardError, "boom")

      status = described_class.call

      expect(status[:active]).to be(false)
      expect(status[:queued_count]).to eq(0)
      expect(status[:running_count]).to eq(0)
      expect(status[:updated_at]).to be_present
    end
  end
end
