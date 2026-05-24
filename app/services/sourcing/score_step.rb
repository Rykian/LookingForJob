module Sourcing
  class ScoreStep
    VERSION = 4

    # Returns [score, breakdown]
    def self.call(offer:, profile:)
      score = 100

      score, tech_details = tech_score(offer, profile, score)
      score, location_details = location_score(offer, profile, score)
      score, commute_details = commute_score(offer, profile, score)
      score = bounded_score(score)

      [ score, {
        technology: tech_details,
        location: location_details,
        commute: commute_details,
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

    # Reads commute_durations purely — no Mapbox calls. CommuteStep is the
    # producer; if the offer was never enriched (no commute_city_id) or no row
    # matches the current origin+mode, the penalty is skipped.
    def self.commute_score(offer, profile, score)
      commute_cfg = profile.dig(:location, :commute)
      return [score, { skipped: true, reason: "no_profile_commute" }] if commute_cfg.blank?
      return [score, { skipped: true, reason: "offer_has_no_commute_city" }] if offer.commute_city_id.nil?

      origin = Commute::City.find_by(normalized_name: Commute::City.normalize(commute_cfg[:origin_city]))
      return [score, { skipped: true, reason: "origin_not_geocoded" }] if origin.nil?

      duration = Commute::Duration.find_by(
        origin_city_id: origin.id,
        destination_city_id: offer.commute_city_id,
        mode: commute_cfg[:mode]
      )
      return [score, { skipped: true, reason: "no_duration_row" }] if duration.nil?

      minutes = duration.duration_minutes
      max = commute_cfg[:max_minutes].to_i

      if minutes > max
        [score - 100, { minutes: minutes, max_minutes: max, mode: commute_cfg[:mode], penalty_reason: "over_max_commute" }]
      else
        [score, { minutes: minutes, max_minutes: max, mode: commute_cfg[:mode], within_max: true }]
      end
    end

    def self.bounded_score(value)
      value.round.clamp(0, 100)
    end
  end
end
