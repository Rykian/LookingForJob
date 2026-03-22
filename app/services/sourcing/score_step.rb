module Sourcing
  class ScoreStep
    # Returns [score, breakdown]
    def self.call(offer:, profile:)
      tech_score, tech_details = tech_subscore(offer, profile)
      remote_score, remote_details = remote_subscore(offer, profile)
      # v1: equal weight for tech and remote
      score = ((tech_score + remote_score) / 2.0).round
      breakdown = {
        technology: tech_details,
        remote_hybrid: remote_details
      }
      [ score, breakdown ]
    end

    def self.tech_subscore(offer, profile)
      user_primary = profile[:technology][:primary].map(&:downcase)
      user_secondary = profile[:technology][:secondary].map(&:downcase)
      offer_primary = Array(offer.primary_technologies).map(&:downcase)
      offer_secondary = Array(offer.secondary_technologies).map(&:downcase)
      # Score: +60 if all user primary in offer primary, +20 if all user secondary in offer secondary
      # -20 if offer primary has tech not in user primary+secondary
      bonus = (user_primary - offer_primary).empty? ? 60 : 0
      secondary_bonus = (user_secondary - offer_secondary).empty? ? 20 : 0
      malus = (offer_primary - (user_primary + user_secondary)).any? ? -20 : 0
      score = [ bonus + secondary_bonus + malus, 0 ].max
      details = {
        user_primary: user_primary,
        user_secondary: user_secondary,
        offer_primary: offer_primary,
        offer_secondary: offer_secondary,
        bonus: bonus,
        secondary_bonus: secondary_bonus,
        malus: malus,
        score: score
      }
      [ score, details ]
    end

    def self.remote_subscore(offer, profile)
      mode = offer.remote || "no"
      preferred = profile[:remote_hybrid][:preferred_modes].map(&:to_s)
      importance = profile[:remote_hybrid][:importance].to_s
      weight = { "low" => 20, "medium" => 40, "high" => 60 }[importance] || 40
      score = preferred.include?(mode) ? weight : 0
      details = { mode: mode, preferred: preferred, importance: importance, score: score }
      # Hybrid: add city and remote days bonus
      if mode == "hybrid"
        allowed_cities = profile[:remote_hybrid][:hybrid][:allowed_cities].map(&:downcase)
        city = (offer.city || "").downcase
        city_bonus = allowed_cities.any? { |allowed| city.include?(allowed) } ? 10 : 0
        days = offer.hybrid_remote_days_min_per_week.to_i
        # Monotonic: 1 day = 0, 5 days = 10
        days_bonus = [ [ days - 1, 0 ].max * 2.5, 10 ].min.to_i
        score += city_bonus + days_bonus
        details.merge!(city: city, allowed_cities: allowed_cities, city_bonus: city_bonus, days: days, days_bonus: days_bonus)
      end
      [ score, details ]
    end
  end
end
