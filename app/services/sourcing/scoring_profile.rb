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
