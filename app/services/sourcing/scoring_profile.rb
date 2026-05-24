require "json"

module Sourcing
  class ScoringProfile
    PROFILE_PATH = Rails.root.join("data", "scoring_profile.json")

    # Memoized at process level for the default path. Tests that pass an
    # explicit path always re-read. Call .reload! after writing the file
    # (or via the ReloadScoringProfile mutation) to force a refresh.
    def self.load(path = PROFILE_PATH)
      return read!(path) unless path == PROFILE_PATH

      @cached ||= read!(path)
    end

    def self.reload!
      @cached = nil
      load
    end

    def self.read!(path)
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

      if data.dig("location", "hybrid")
        raise "Invalid location.hybrid" unless data.dig("location", "hybrid").is_a?(Hash)
        raise "Missing location.hybrid.remote_days_min_per_week" unless numeric?(data.dig("location", "hybrid", "remote_days_min_per_week"))
      end

      validate_commute!(data.dig("location", "commute")) if data.dig("location", "commute")

      true
    end

    COMMUTE_MODES = %w[driving cycling walking].freeze

    def self.validate_commute!(commute)
      raise "Invalid commute" unless commute.is_a?(Hash)
      raise "Missing commute.origin_city" unless commute["origin_city"].is_a?(String) && !commute["origin_city"].strip.empty?
      raise "Missing commute.max_minutes" unless commute["max_minutes"].is_a?(Integer) && commute["max_minutes"].positive?
      raise "Invalid commute.mode" unless COMMUTE_MODES.include?(commute["mode"])
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
