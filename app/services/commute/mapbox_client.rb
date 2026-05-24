# frozen_string_literal: true

require "faraday"
require "faraday/retry"

module Commute
  class ApiError < StandardError; end

  # Thin Faraday wrapper around Mapbox Geocoding v5 and Directions v5.
  # Token comes from ENV["MAPBOX_TOKEN"]; missing token raises loudly.
  class MapboxClient
    BASE_URL = "https://api.mapbox.com"
    GEOCODE_PATH = "/geocoding/v5/mapbox.places"
    DIRECTIONS_PATH = "/directions/v5/mapbox"

    def initialize(token: ENV.fetch("MAPBOX_TOKEN"), connection: nil)
      @token = token
      @connection = connection
    end

    # @return [Hash, nil] { canonical_name:, latitude:, longitude: } or nil when no result.
    def geocode(city)
      query = CGI.escape(city.to_s)
      response = connection.get("#{GEOCODE_PATH}/#{query}.json", {
        access_token: @token,
        country: "fr",
        types: "place",
        limit: 1,
        language: "fr",
      })
      raise ApiError, "Mapbox geocode HTTP #{response.status} for city=#{city.inspect}: #{response.body}" unless response.success?

      feature = response.body.is_a?(Hash) ? response.body["features"]&.first : nil
      return nil unless feature

      lng, lat = feature["center"]
      { canonical_name: feature["text"], latitude: lat, longitude: lng }
    end

    # @return [Integer, nil] one-way travel time in whole minutes, or nil when no route exists.
    def duration(origin:, destination:, mode:)
      coords = "#{origin[:longitude]},#{origin[:latitude]};#{destination[:longitude]},#{destination[:latitude]}"
      response = connection.get("#{DIRECTIONS_PATH}/#{mode}/#{coords}", {
        access_token: @token,
        overview: "false",
        alternatives: "false",
      })
      raise ApiError, "Mapbox directions HTTP #{response.status} (#{mode}): #{response.body}" unless response.success?

      route = response.body.is_a?(Hash) ? response.body["routes"]&.first : nil
      return nil unless route && route["duration"]

      (route["duration"].to_f / 60.0).round
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |conn|
        conn.request :retry, max: 2, interval: 0.3, backoff_factor: 2,
                     exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed],
                     retry_statuses: [502, 503, 504]
        conn.response :json, content_type: /\bjson$/
        conn.options.timeout = 10
        conn.options.open_timeout = 5
      end
    end
  end
end
