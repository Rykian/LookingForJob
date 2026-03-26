module Sourcing
  class ScoreStep
    VERSION = 2

    # Returns [score, breakdown]
    def self.call(offer:, profile:)
      score = 100

      score, tech_details = tech_score(offer, profile, score)
      score, location_details = location_score(offer, profile, score)
      score = bounded_score(score)

      [ score, {
        technology: tech_details,
        location: location_details,
      }, ]
    end

    # Returns [score, details]
    def self.tech_score(offer, profile, score)
      details = {}
      user_primary = profile[:technology][:primary].map { |tech| tech.downcase.gsub(/[^a-z0-9]+/, "") }
      user_secondary = profile[:technology][:secondary].map { |tech| tech.downcase.gsub(/[^a-z0-9]+/, "") }
      offer_primary = Array(offer.primary_technologies).map { |tech| tech.downcase.gsub(/[^a-z0-9]+/, "") }
      offer_secondary = Array(offer.secondary_technologies).map { |tech| tech.downcase.gsub(/[^a-z0-9]+/, "") }
      if offer_primary.empty?
        details[:warning] = "offer_has_no_technologies"
        return [0, details]
      end

      # Remove points for each required technology that the user doesn't have in either primary or secondary
      required_missing = offer_primary - (user_primary + user_secondary)
      score = score - (required_missing.size * (100 / offer_primary.length))
      if required_missing.any?
        details[:missing_required_technologies] = required_missing
        details[:penalty_reason] = "missing_required_technologies"
      end

      # Add points if the user has at least one of the secondary technologies in their secondary list
      secondary_matches = offer_secondary & (user_primary + user_secondary)
      if secondary_matches.any?
        details[:matching_secondary_technologies] = secondary_matches
        details[:bonus_reason] = "matching_secondary_technologies"
      end
      score = score + (secondary_matches.size * 3)
      [ score, details ]
    end

    def self.location_score(offer, profile, score)
      mode = offer.location_mode.to_s.downcase.tr("_", "-")
      preference = Array(profile.dig(:location, :preference)).map { |v| v.to_s.downcase }
      rank = preference.index(mode)

      if rank.nil?
        details = { mode: mode, preference: preference, penalty_reason: "not_in_preference" }
        score = score - 100
        return [ score, details ]
      end

      if %w[hybrid on-site].include?(mode)
        city = (offer.city || "").downcase
        profile_cities = resolved_city_preferences(profile, mode)
        # If the offer is in a mode that requires location matching,
        # but the city doesn't match any of the allowed cities, apply a penalty
        if profile_cities&.none? { |allowed| city.include?(allowed) }
          details = { mode:, city:, allowed_cities: profile_cities, penalty_reason: "city_not_allowed" }
          score = score - 100
          return [ score, details ]
        end
      end

      details = {}

      if mode == "hybrid"
        remote_days_min = profile.dig(:location, :hybrid, :remote_days_min_per_week).to_i
        offer_remote_days = offer.hybrid_remote_days_min_per_week.to_i
        if offer_remote_days < remote_days_min
          details = details.merge({ mode:, offer_remote_days:, required_remote_days: remote_days_min, penalty_reason: "hybrid_remote_days_insufficient" })
          score = score - 100
          return [ score, details ]
        end
        malus = (5 - offer_remote_days) * 10
        score = score - malus
        if malus.positive?
          details = details.merge({ mode:, offer_remote_days:, penalty_reason: "hybrid_remote_days", malus: })
        end
      end

      if rank.positive?
        malus = rank * 20
        score = score - malus
        return [ score, details.merge({ mode: mode, preference: preference, rank: rank, penalty_reason: "lower_preference_rank", malus: malus }) ]
      end

      [score, details]
    end

    def self.resolved_city_preferences(profile, mode)
      location = profile[:location] || {}
      default_cities = Array(location[:city]).map(&:downcase)

      override = case mode
      when "hybrid"
        location.dig(:hybrid, :city)
      when "on-site"
        location.dig(:on_site, :city)
      else
        nil
      end

      Array(override || default_cities).map(&:downcase)
    end

    def self.bounded_score(value)
      value.round.clamp(0, 100)
    end
  end
end
