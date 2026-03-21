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
      # Minimal v1 validation
      raise "Missing technology.primary" unless data.dig("technology", "primary").is_a?(Array)
      raise "Missing technology.secondary" unless data.dig("technology", "secondary").is_a?(Array)
      raise "Missing remote_hybrid.importance" unless data.dig("remote_hybrid", "importance")
      raise "Missing remote_hybrid.preferred_modes" unless data.dig("remote_hybrid", "preferred_modes").is_a?(Array)
      raise "Missing remote_hybrid.hybrid.allowed_cities" unless data.dig("remote_hybrid", "hybrid", "allowed_cities").is_a?(Array)
      true
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
