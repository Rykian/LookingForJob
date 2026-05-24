# frozen_string_literal: true

module Commute
  # Resolves a city name to a persisted Commute::City row, geocoding via Mapbox
  # the first time the city is seen. The DB row is the cache; subsequent calls
  # for the same normalized name short-circuit on a SELECT.
  class Geocoder
    def self.city_for(name, client: MapboxClient.new)
      new(client: client).city_for(name)
    end

    def initialize(client: MapboxClient.new)
      @client = client
    end

    def city_for(name)
      return nil if name.blank?

      normalized = Commute::City.normalize(name)
      existing = Commute::City.find_by(normalized_name: normalized)
      return existing if existing

      result = @client.geocode(name)
      return nil if result.nil?

      # Store under the canonical Mapbox name's normalized form so variants
      # like "saint etienne" and "Saint-Étienne" converge on the same row.
      canonical_normalized = Commute::City.normalize(result[:canonical_name])
      Commute::City.create_or_find_by!(normalized_name: canonical_normalized) do |row|
        row.name = result[:canonical_name]
        row.latitude = result[:latitude]
        row.longitude = result[:longitude]
        row.geocoded_at = Time.current
      end
    rescue ApiError => e
      Rails.logger.warn("Commute::Geocoder failed for name=#{name.inspect}: #{e.message}")
      nil
    end
  end
end
