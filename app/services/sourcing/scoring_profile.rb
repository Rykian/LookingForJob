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
      raise "Missing technology.weights" unless data.dig("technology", "weights").is_a?(Hash)
      raise "Missing technology.weights.primary_coverage" unless numeric?(data.dig("technology", "weights", "primary_coverage"))
      raise "Missing technology.weights.secondary_coverage" unless numeric?(data.dig("technology", "weights", "secondary_coverage"))
      raise "Missing technology.weights.unknown_penalty" unless numeric?(data.dig("technology", "weights", "unknown_penalty"))

      raise "Missing remote_hybrid.importance" unless data.dig("remote_hybrid", "importance")
      raise "Missing remote_hybrid.preferred_modes" unless data.dig("remote_hybrid", "preferred_modes").is_a?(Array)
      raise "Missing remote_hybrid.hybrid.allowed_cities" unless data.dig("remote_hybrid", "hybrid", "allowed_cities").is_a?(Array)
      raise "Missing remote_hybrid.hybrid.hybrid_remote_days_min_per_week" unless numeric?(data.dig("remote_hybrid", "hybrid", "hybrid_remote_days_min_per_week"))
      raise "Missing remote_hybrid.hybrid.days_weight" unless numeric?(data.dig("remote_hybrid", "hybrid", "days_weight"))

      raise "Missing weights" unless data["weights"].is_a?(Hash)
      raise "Missing weights.technology" unless numeric?(data.dig("weights", "technology"))
      raise "Missing weights.remote_hybrid" unless numeric?(data.dig("weights", "remote_hybrid"))
      raise "Missing weights.location" unless numeric?(data.dig("weights", "location"))

      unless %w[low medium high].include?(data.dig("remote_hybrid", "importance").to_s)
        raise "Invalid remote_hybrid.importance"
      end

      unless (0.0..1.0).cover?(data.dig("remote_hybrid", "hybrid", "days_weight").to_f)
        raise "Invalid remote_hybrid.hybrid.days_weight"
      end

      agg_total = %w[technology remote_hybrid location].sum { |key| data.dig("weights", key).to_f }
      raise "Invalid weights total" if agg_total <= 0

      true
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
