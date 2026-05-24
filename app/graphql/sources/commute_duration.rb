# frozen_string_literal: true

module Sources
  # Batches Commute::Duration lookups by destination city for a fixed
  # (origin_city_id, mode) pair. Each unique destination is resolved with a
  # single SQL query per (origin, mode) group, regardless of how many offers
  # reference it in the same GraphQL query.
  class CommuteDuration < GraphQL::Dataloader::Source
    def initialize(origin_city_id:, mode:)
      @origin_city_id = origin_city_id
      @mode = mode
    end

    def fetch(destination_city_ids)
      durations = ::Commute::Duration
        .where(origin_city_id: @origin_city_id, mode: @mode, destination_city_id: destination_city_ids)
        .pluck(:destination_city_id, :duration_minutes)
        .to_h
      destination_city_ids.map { |id| durations[id] }
    end
  end
end
