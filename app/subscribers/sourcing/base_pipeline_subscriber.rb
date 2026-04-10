module Sourcing
  class BasePipelineSubscriber
    def emit(event)
      payload = event.fetch(:payload)
      job_class.perform_later(payload.fetch(:offer_id), force: payload.fetch(:force, false))
    end

    private

    def job_class
      raise NotImplementedError
    end
  end
end
