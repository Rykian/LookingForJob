module Sourcing
  class ScoreStep
    # Returns [score, breakdown]
    def self.call(offer:, profile:)
      tech_score, tech_details = tech_subscore(offer, profile)
      if tech_details[:no_primary_technologies] || tech_details[:no_primary_match]
        return [ 0, { technology: tech_details, remote_hybrid: nil, location: nil, gate_reason: tech_details[:gate_reason] } ]
      end

      remote_score, remote_details = remote_subscore(offer, profile)
      location_score, location_details = location_subscore(offer, profile)

      if offer.remote.to_s == "hybrid" && location_score.zero?
        remote_score = 0
        remote_details = remote_details.merge(score: 0, forced_to_zero_by_location: true)
      end

      normalized_weights = aggregation_weights(profile)
      score = weighted_average(
        {
          technology: tech_score,
          remote_hybrid: remote_score,
          location: location_score
        },
        normalized_weights
      )

      breakdown = {
        technology: tech_details,
        remote_hybrid: remote_details,
        location: location_details,
        weights: normalized_weights
      }
      [ score, breakdown ]
    end

    def self.tech_subscore(offer, profile)
      user_primary = profile[:technology][:primary].map(&:downcase)
      user_secondary = profile[:technology][:secondary].map(&:downcase)
      offer_primary = Array(offer.primary_technologies).map(&:downcase)
      offer_secondary = Array(offer.secondary_technologies).map(&:downcase)

      if offer_primary.empty?
        details = {
          user_primary: user_primary, user_secondary: user_secondary,
          offer_primary: offer_primary, offer_secondary: offer_secondary,
          no_primary_technologies: true,
          gate_reason: "missing_offer_primary",
          score: 0
        }
        return [ 0, details ]
      end

      if user_primary.any? && (offer_primary & user_primary).empty?
        details = {
          user_primary: user_primary, user_secondary: user_secondary,
          offer_primary: offer_primary, offer_secondary: offer_secondary,
          no_primary_match: true,
          gate_reason: "no_primary_overlap",
          score: 0
        }
        return [ 0, details ]
      end

      tech_weights = technology_weights(profile)
      known_user_techs = (user_primary + user_secondary).uniq
      primary_coverage = ratio((offer_primary & user_primary).size, user_primary.size)
      secondary_coverage = ratio((offer_secondary & user_secondary).size, user_secondary.size)
      unknown_primary_ratio = ratio((offer_primary - known_user_techs).size, offer_primary.size)

      score = bounded_score(
        100.0 * (
          tech_weights[:primary_coverage] * primary_coverage +
          tech_weights[:secondary_coverage] * secondary_coverage -
          tech_weights[:unknown_penalty] * unknown_primary_ratio
        )
      )

      details = {
        primary_coverage: primary_coverage.round(3),
        secondary_coverage: secondary_coverage.round(3),
        unknown_primary_ratio: unknown_primary_ratio.round(3),
        score: score
      }
      [ score, details ]
    end

    def self.remote_subscore(offer, profile)
      mode = offer.remote || "no"
      remote_profile = profile[:remote_hybrid] || {}
      preferred = Array(remote_profile[:preferred_modes]).map(&:to_s)
      importance = remote_profile[:importance].to_s
      importance_factor = importance_factor_for(importance)
      days_weight = hybrid_days_weight(profile)
      mode_match_score = preferred.include?(mode) ? 100.0 : 0.0

      hybrid_days_fit = nil
      raw_score = mode_match_score
      if mode == "hybrid"
        target_days = preferred_hybrid_days(profile)
        days = offer.hybrid_remote_days_min_per_week.to_i
        hybrid_days_fit = hybrid_day_fit(days, target_days)
        raw_score = (mode_match_score * (1.0 - days_weight)) + (hybrid_days_fit * days_weight)
      end

      score = bounded_score(raw_score * importance_factor)
      details = {
        mode: mode,
        mode_match_score: mode_match_score.round,
        importance_factor: importance_factor,
        hybrid_days_fit: hybrid_days_fit&.round,
        score: score
      }

      [ score, details ]
    end

    def self.location_subscore(offer, profile)
      allowed_cities = Array(profile.dig(:remote_hybrid, :hybrid, :allowed_cities)).map(&:downcase)
      city = (offer.city || "").downcase
      mode = (offer.remote || "no").to_s

      # City constraints apply only to hybrid offers.
      return [ 100, { match_type: "not_hybrid", score: 100 } ] unless mode == "hybrid"

      if allowed_cities.empty?
        return [ 100, { match_type: "no_constraint", score: 100 } ]
      end

      if city.empty?
        return [ 0, { match_type: "missing_city", score: 0 } ]
      end

      exact_match = allowed_cities.include?(city)
      substring_match = allowed_cities.any? { |allowed| city.include?(allowed) }

      if exact_match
        [ 100, { match_type: "exact", score: 100 } ]
      elsif substring_match
        [ 100, { match_type: "substring", score: 100 } ]
      else
        [ 0, { match_type: "none", score: 0 } ]
      end
    end

    def self.technology_weights(profile)
      raw = profile.dig(:technology, :weights) || {}
      normalized = normalize_weights(
        primary_coverage: raw.fetch(:primary_coverage, 0.75),
        secondary_coverage: raw.fetch(:secondary_coverage, 0.15),
        unknown_penalty: raw.fetch(:unknown_penalty, 0.10)
      )
      {
        primary_coverage: normalized[:primary_coverage],
        secondary_coverage: normalized[:secondary_coverage],
        unknown_penalty: normalized[:unknown_penalty]
      }
    end

    def self.aggregation_weights(profile)
      raw = profile[:weights] || {}
      normalize_weights(
        technology: raw.fetch(:technology, 70.0),
        remote_hybrid: raw.fetch(:remote_hybrid, 20.0),
        location: raw.fetch(:location, 10.0)
      )
    end

    def self.preferred_hybrid_days(profile)
      profile.dig(:remote_hybrid, :hybrid, :hybrid_remote_days_min_per_week).to_i.clamp(1, 5)
    end

    def self.hybrid_days_weight(profile)
      weight = profile.dig(:remote_hybrid, :hybrid, :days_weight)
      return 0.35 if weight.nil?

      weight.to_f.clamp(0.0, 1.0)
    end

    def self.importance_factor_for(importance)
      {
        "low" => 0.5,
        "medium" => 0.75,
        "high" => 1.0
      }.fetch(importance, 0.75)
    end

    def self.hybrid_day_fit(days, target_days)
      return 100.0 if days >= target_days

      ratio(days, target_days) * 100.0
    end

    def self.weighted_average(scores, weights)
      value =
        (scores[:technology].to_f * weights[:technology]) +
        (scores[:remote_hybrid].to_f * weights[:remote_hybrid]) +
        (scores[:location].to_f * weights[:location])
      bounded_score(value)
    end

    def self.ratio(value, total)
      return 1.0 if total.to_i <= 0

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
