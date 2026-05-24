# frozen_string_literal: true

module Commute
  # Resolves the travel time between two cities for a given Mapbox profile.
  # Caches results in commute_durations; fresh rows are returned without hitting
  # Mapbox. Stale rows (computed_at < 30 days ago) are refreshed in place.
  class DurationCalculator
    def self.minutes(origin:, destination:, mode:, client: MapboxClient.new, geocoder: Geocoder.new(client: client))
      new(client: client, geocoder: geocoder).minutes(origin: origin, destination: destination, mode: mode)
    end

    def initialize(client: MapboxClient.new, geocoder: Geocoder.new(client: client))
      @client = client
      @geocoder = geocoder
    end

    def minutes(origin:, destination:, mode:)
      origin_city = @geocoder.city_for(origin)
      destination_city = @geocoder.city_for(destination)
      return nil if origin_city.nil? || destination_city.nil?
      return 0 if origin_city.id == destination_city.id

      row = Commute::Duration.find_by(
        origin_city_id: origin_city.id,
        destination_city_id: destination_city.id,
        mode: mode.to_s
      )
      return row.duration_minutes if row&.fresh?

      fetched = @client.duration(
        origin: { latitude: origin_city.latitude, longitude: origin_city.longitude },
        destination: { latitude: destination_city.latitude, longitude: destination_city.longitude },
        mode: mode.to_s
      )
      return row&.duration_minutes if fetched.nil?

      upsert_row(row, origin_city, destination_city, mode, fetched)
      fetched
    rescue ApiError => e
      Rails.logger.warn("Commute::DurationCalculator failed origin=#{origin.inspect} dest=#{destination.inspect} mode=#{mode}: #{e.message}")
      row&.duration_minutes
    end

    private

    def upsert_row(row, origin_city, destination_city, mode, minutes)
      if row
        row.update!(duration_minutes: minutes, computed_at: Time.current)
      else
        Commute::Duration.create!(
          origin_city: origin_city,
          destination_city: destination_city,
          mode: mode.to_s,
          duration_minutes: minutes,
          computed_at: Time.current
        )
      end
    rescue ActiveRecord::RecordNotUnique
      # Lost a race with another worker — the row now exists, ignore.
    end
  end
end
