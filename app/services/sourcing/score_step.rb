module Sourcing
  class ScoreStep
    # Returns [score, breakdown]
    def self.call(offer:, profile:)
      tech_score, tech_details = tech_subscore(offer, profile)
      if tech_details[:no_primary_technologies]
        return [ 0, { technology: tech_details, location_mode: nil, location_city: nil, gate_reason: tech_details[:gate_reason] } ]
      end

      mode_score, mode_details = location_mode_subscore(offer, profile)
      city_score, city_details = location_city_subscore(offer, profile)

      if normalized_offer_mode(offer) == "hybrid" && city_score.zero?
        mode_score = 0
        mode_details = mode_details.merge(score: 0, forced_to_zero_by_city: true)
      end

      normalized_weights = aggregation_weights(profile)
      score = weighted_average(
        {
          technology: tech_score,
          location_mode: mode_score,
          location_city: city_score
        },
        normalized_weights
      )

      breakdown = {
        technology: tech_details,
        location_mode: mode_details,
        location_city: city_details,
        weights: normalized_weights
      }
      [ score, breakdown ]
    end

    def self.tech_subscore(offer, profile)
      user_primary = profile[:technology][:primary].map(&:downcase)
      user_secondary = profile[:technology][:secondary].map(&:downcase)
      offer_primary = Array(offer.primary_technologies).map(&:downcase)
      offer_secondary = Array(offer.secondary_technologies).map(&:downcase)
      penalties = profile[:penalties] || {}
      bonuses = profile[:bonuses] || {}

      if offer_primary.empty?
        details = {
          no_primary_technologies: true,
          gate_reason: "missing_offer_primary",
          score: 0
        }
        return [ 0, details ]
      end

      known_user_techs = (user_primary + user_secondary).uniq
      primary_matches = (offer_primary & user_primary).size
      unknown_required_count = (offer_primary - known_user_techs).size
      secondary_match_bonus = (offer_secondary & user_secondary).any? ? bonuses.fetch(:secondary_match, 10).to_i : 0
      secondary_on_primary_bonus = (offer_primary & user_secondary).any? ? bonuses.fetch(:secondary_on_primary_match, 10).to_i : 0
      unknown_required_penalty = unknown_required_count * penalties.fetch(:unknown_primary_required, 20).to_i

      base_score = ratio(primary_matches, offer_primary.size) * 100.0
      score = bounded_score(base_score - unknown_required_penalty + secondary_match_bonus + secondary_on_primary_bonus)

      details = {
        primary_match_ratio: ratio(primary_matches, offer_primary.size).round(3),
        unknown_required_count: unknown_required_count,
        penalties_applied: {
          unknown_primary_required: unknown_required_penalty
        },
        bonuses_applied: {
          secondary_match: secondary_match_bonus,
          secondary_on_primary_match: secondary_on_primary_bonus
        },
        score: score
      }
      [ score, details ]
    end

    def self.location_mode_subscore(offer, profile)
      mode = normalized_offer_mode(offer)
      preference = Array(profile.dig(:location, :preference)).map(&:to_s)
      penalties = profile[:penalties] || {}
      rank = preference.index(mode)

      if rank.nil?
        return [ 0, { mode: mode, preference: preference, penalty_reason: "not_in_preference", score: 0 } ]
      end

      step = penalties.fetch(:preference_rank_step, 40).to_i
      score = bounded_score(100 - (rank * step))
      details = {
        mode: mode,
        preference: preference,
        rank: rank,
        score: score
      }
      [ score, details ]
    end

    def self.location_city_subscore(offer, profile)
      mode = normalized_offer_mode(offer)
      allowed_cities = resolved_city_preferences(profile, mode)
      city = (offer.city || "").downcase

      return [ 100, { mode: mode, match_type: "not_applicable", score: 100 } ] if mode == "remote"

      if allowed_cities.empty?
        return [ 100, { mode: mode, match_type: "no_constraint", score: 100 } ]
      end

      if city.empty?
        return [ 0, { mode: mode, match_type: "missing_city", score: 0 } ]
      end

      exact_match = allowed_cities.include?(city)
      substring_match = allowed_cities.any? { |allowed| city.include?(allowed) }

      if exact_match
        [ 100, { mode: mode, match_type: "exact", score: 100 } ]
      elsif substring_match
        [ 100, { mode: mode, match_type: "substring", score: 100 } ]
      else
        [ 0, { mode: mode, match_type: "none", penalty_reason: "city_not_allowed", score: 0 } ]
      end
    end

    def self.aggregation_weights(profile)
      raw = profile[:weights] || {}
      normalize_weights(
        technology: raw.fetch(:technology, 70.0),
        location_mode: raw.fetch(:location_mode, 20.0),
        location_city: raw.fetch(:location_city, 10.0)
      )
    end

    def self.weighted_average(scores, weights)
      value =
        (scores[:technology].to_f * weights[:technology]) +
        (scores[:location_mode].to_f * weights[:location_mode]) +
        (scores[:location_city].to_f * weights[:location_city])
      bounded_score(value)
    end

    def self.normalized_offer_mode(offer)
      {
        "yes" => "remote",
        "hybrid" => "hybrid",
        "no" => "on-site"
      }.fetch(offer.remote.to_s, "on-site")
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

    def self.ratio(value, total)
      return 0.0 if total.to_i <= 0

      value.to_f / total.to_f
    end

    def self.normalize_weights(weights)
      cleaned = weights.transform_values { |weight| weight.to_f.positive? ? weight.to_f : 0.0 }
      total = cleaned.values.sum
      return cleaned.transform_values { 0.0 } if total <= 0

      cleaned.transform_values { |weight| weight / total }
    end

    def self.bounded_score(value)
      value.round.clamp(0, 100)
    end
  end
end
