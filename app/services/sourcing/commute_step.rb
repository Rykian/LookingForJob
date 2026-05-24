module Sourcing
  # Resolves a JobOffer's city to a Commute::City and computes the travel time
  # from the configured origin. Read by ScoreStep (commute penalty) and by the
  # offers GraphQL list (duration JOIN).
  class CommuteStep
    VERSION = 1

    Result = Struct.new(:status, :commute_city_id, :canonical_city, :duration_minutes, keyword_init: true)

    def self.call(offer:, profile:, client: Commute::MapboxClient.new)
      geocoder = Commute::Geocoder.new(client: client)
      calculator = Commute::DurationCalculator.new(client: client, geocoder: geocoder)
      new(geocoder: geocoder, calculator: calculator).call(offer: offer, profile: profile)
    end

    def initialize(geocoder:, calculator:)
      @geocoder = geocoder
      @calculator = calculator
    end

    def call(offer:, profile:)
      commute = profile.dig(:location, :commute)
      return skipped if commute.blank?
      return skipped if offer.location_mode == "remote"
      return skipped if offer.city.blank?

      destination = @geocoder.city_for(offer.city)
      return skipped if destination.nil?

      duration = @calculator.minutes(
        origin: commute[:origin_city],
        destination: destination.name,
        mode: commute[:mode]
      )

      Result.new(
        status: :ok,
        commute_city_id: destination.id,
        canonical_city: destination.name,
        duration_minutes: duration
      )
    end

    private

    def skipped
      Result.new(status: :skipped, commute_city_id: nil, canonical_city: nil, duration_minutes: nil)
    end
  end
end
