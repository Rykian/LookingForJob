module Sourcing
  # Deduplicates job offer technologies using ActiveJob::Continuation so the
  # long-running work (many LLM calls + a full offer rewrite) is checkpointed
  # and resumes from the last batch / last offer after an interruption.
  class DedupTechnologiesJob < ApplicationJob
    include ActiveJob::Continuable
    include Sidekiq::Throttled::Job

    # Avoid concurrent runs since they would step on each other's alias map and
    # snapshot.
    sidekiq_throttle(concurrency: {
      limit: 1,
      ttl: 6.hours.to_i,
    })

    # Redis key holding the frozen work list. Shared across workers so a resume
    # on a different host can still read it. TTL guards against orphaned keys if
    # the job dies permanently mid-run (resume happens well within this window).
    SNAPSHOT_KEY = "dedup_technologies:snapshot".freeze
    SNAPSHOT_TTL = 1.day.to_i

    def perform
      @service = DedupTechnologiesService.new

      # Freeze the work list so batch boundaries stay stable across resumes.
      step :snapshot_technologies do
        write_snapshot(@service.raw_technologies)
      end

      # LLM-canonicalize batch by batch; cursor = next batch index. The alias
      # map is persisted to Redis after each batch, so it doubles as durable
      # resume state.
      step :build_alias_map do |step|
        batches = snapshot_batches
        alias_map = step.cursor ? load_alias_map : {}

        (step.cursor || 0).upto(batches.size - 1) do |i|
          alias_map.merge!(@service.batch_alias_map(batches[i]))
          @service.write_alias_map(alias_map)
          step.set! i + 1
        end
      end

      # Rewrite every offer; cursor = last processed offer id. Idempotent, so
      # re-applying the canonical map on resume is a no-op.
      step :apply_alias_map do |step|
        alias_map = load_alias_map
        JobOffer
          .where(disabled: false, rejected: false)
          .find_each(start: step.cursor) do |offer|
            @service.canonicalize_offer!(offer, alias_map)
            step.advance! from: offer.id
          end
      end

      step :canonicalize_scoring_profile do
        @service.canonicalize_scoring_profile!(load_alias_map)
      end

      step :write_common_technologies do
        @service.write_common_technologies(@service.top_canonical_technologies)
      end

      step :cleanup do
        delete_snapshot
      end
    end

    private

    def write_snapshot(techs)
      Sidekiq.redis { |r| r.set(SNAPSHOT_KEY, JSON.generate(techs), ex: SNAPSHOT_TTL) }
    end

    def delete_snapshot
      Sidekiq.redis { |r| r.del(SNAPSHOT_KEY) }
    end

    def snapshot_batches
      raw = Sidekiq.redis { |r| r.get(SNAPSHOT_KEY) }
      raise "dedup snapshot missing from Redis (#{SNAPSHOT_KEY}); restart the job" if raw.nil?

      JSON.parse(raw).each_slice(DedupTechnologiesService::BATCH_SIZE).to_a
    end

    def load_alias_map
      TechnologyStore.read_alias_map
    end
  end
end
