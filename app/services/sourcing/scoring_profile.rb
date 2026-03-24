require "json"

module Sourcing
  class ScoringProfile
    PROFILE_PATH = Rails.root.join("data", "scoring_profile.json")

    def self.load(path = PROFILE_PATH)
      json = File.read(path)
      data = JSON.parse(json)
      validate!(data)
      symbolize_keys(data)
    rescue Errno::ENOENT
      raise "Scoring profile not found at #{path}"
    rescue JSON::ParserError
      raise "Invalid JSON in scoring profile at #{path}"
    end

    def self.validate!(data)
      raise "Missing technology.primary" unless data.dig("technology", "primary").is_a?(Array)
      raise "Missing technology.secondary" unless data.dig("technology", "secondary").is_a?(Array)
      raise "Missing location" unless data["location"].is_a?(Hash)
      raise "Missing location.preference" unless data.dig("location", "preference").is_a?(Array)
      raise "Invalid location.preference" unless valid_preference?(data.dig("location", "preference"))

      if data.dig("location", "city")
        raise "Invalid location.city" unless string_array?(data.dig("location", "city"))
      end

      if data.dig("location", "hybrid")
        raise "Invalid location.hybrid" unless data.dig("location", "hybrid").is_a?(Hash)
        if data.dig("location", "hybrid", "city")
          raise "Invalid location.hybrid.city" unless string_array?(data.dig("location", "hybrid", "city"))
        end
        raise "Missing location.hybrid.remote_days_min_per_week" unless numeric?(data.dig("location", "hybrid", "remote_days_min_per_week"))
      end

      if data.dig("location", "on_site")
        raise "Invalid location.on_site" unless data.dig("location", "on_site").is_a?(Hash)
        if data.dig("location", "on_site", "city")
          raise "Invalid location.on_site.city" unless string_array?(data.dig("location", "on_site", "city"))
        end
      end

      raise "Missing penalties" unless data["penalties"].is_a?(Hash)
      raise "Missing penalties.unknown_primary_required" unless numeric?(data.dig("penalties", "unknown_primary_required"))
      raise "Missing penalties.preference_rank_step" unless numeric?(data.dig("penalties", "preference_rank_step"))
      raise "Missing penalties.not_in_preference" unless numeric?(data.dig("penalties", "not_in_preference"))
      raise "Missing penalties.city_not_allowed" unless numeric?(data.dig("penalties", "city_not_allowed"))

      raise "Missing bonuses" unless data["bonuses"].is_a?(Hash)
      raise "Missing bonuses.secondary_match" unless numeric?(data.dig("bonuses", "secondary_match"))
      raise "Missing bonuses.secondary_on_primary_match" unless numeric?(data.dig("bonuses", "secondary_on_primary_match"))

      raise "Missing weights" unless data["weights"].is_a?(Hash)
      raise "Missing weights.technology" unless numeric?(data.dig("weights", "technology"))
      raise "Missing weights.location_mode" unless numeric?(data.dig("weights", "location_mode"))
      raise "Missing weights.location_city" unless numeric?(data.dig("weights", "location_city"))

      agg_total = %w[technology location_mode location_city].sum { |key| data.dig("weights", key).to_f }
      raise "Invalid weights total" if agg_total <= 0

      true
    end

    def self.valid_preference?(values)
      values.is_a?(Array) && values.any? && (values - ["remote", "hybrid", "on-site"]).empty? && values.uniq == values
    end

    def self.string_array?(values)
      values.is_a?(Array) && values.all? { |value| value.is_a?(String) && value.strip != "" }
    end

    def self.numeric?(value)
      Float(value)
      true
    rescue ArgumentError, TypeError
      false
    end

    def self.symbolize_keys(obj)
      case obj
      when Hash
        obj.transform_keys(&:to_sym).transform_values { |v| symbolize_keys(v) }
      when Array
        obj.map { |v| symbolize_keys(v) }
      else
        obj
      end
    end
  end
end
