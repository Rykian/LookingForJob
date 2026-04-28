# frozen_string_literal: true

require "sidekiq/api"

module Sourcing
  class JobStatusService
    SOURCE_JOB_PREFIX = "Sourcing::"

    class << self
      def call
        queued = queued_count
        running = running_count

        {
          active: (queued + running).positive?,
          queued_count: queued,
          running_count: running,
          updated_at: Time.current.iso8601,
        }
      rescue StandardError
        idle_status
      end

      def idle_status
        {
          active: false,
          queued_count: 0,
          running_count: 0,
          updated_at: Time.current.iso8601,
        }
      end

      private

      def queued_count
        Sidekiq::Queue.all.sum do |queue|
          queue.count do |job|
            sourcing_job_class?(extract_job_class(job.item))
          end
        end
      end

      def running_count
        Sidekiq::Workers.new.count do |_process_id, _thread_id, work|
          payload = work.is_a?(Hash) ? work["payload"] : nil
          sourcing_job_class?(extract_job_class(payload))
        end
      end

      def extract_job_class(payload)
        return nil unless payload.is_a?(Hash)

        wrapped = payload["wrapped"] || payload[:wrapped]
        return wrapped if wrapped.is_a?(String)

        args = payload["args"] || payload[:args]
        first_arg = args.is_a?(Array) ? args.first : nil
        if first_arg.is_a?(Hash)
          job_class = first_arg["job_class"] || first_arg[:job_class]
          return job_class if job_class.is_a?(String)
        end

        klass = payload["class"] || payload[:class]
        klass if klass.is_a?(String)
      end

      def sourcing_job_class?(job_class)
        job_class&.start_with?(SOURCE_JOB_PREFIX)
      end
    end
  end
end
