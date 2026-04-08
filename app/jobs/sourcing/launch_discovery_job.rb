module Sourcing
  class LaunchDiscoveryJob < ApplicationJob
    WORK_MODE_UNSUPPORTED_SOURCES = %w[france_travail].freeze
    SUPPORTED_WORK_MODES = %w[remote hybrid on-site].freeze

    def perform(force: false)
      profile = Sourcing::ScoringProfile.load
      keywords = parse_env_list("KEYWORDS") || parse_profile_list!(profile: profile, path: %i[technology primary], label: "technology.primary")
      work_modes = parse_env_list("WORK_MODE") || parse_profile_list!(profile: profile, path: %i[location preference], label: "location.preference")
      validate_work_modes!(work_modes)

      Sourcing::Providers.registry.sources.each do |source|
        provider = Sourcing::Providers.registry.fetch(source)
        modes_for_source = supports_work_mode_filter_for_source?(source: source, provider: provider) ? work_modes : [work_modes.first]

        keywords.each do |keyword|
          modes_for_source.each do |work_mode|
            DiscoveryJob.perform_later(source:, keyword:, work_mode:, force:)
          end
        end
      end
    end

    private

    def parse_env_list(key)
      raw_value = ENV[key]

      return nil if raw_value.blank?

      parse_list!(raw_value:, source_label: "Environment variable #{key}")
    end

    def parse_profile_list!(profile:, path:, label:)
      raw_values = profile.dig(*path)
      unless raw_values.is_a?(Array)
        raise ArgumentError, "Missing required scoring profile field: #{label}"
      end

      values = raw_values.map(&:to_s).map(&:strip).reject(&:blank?).uniq

      if values.empty?
        raise ArgumentError, "Scoring profile #{label} must contain at least one value"
      end

      values
    end

    def parse_list!(raw_value:, source_label:)
      values = raw_value.split(",").map(&:strip).reject(&:blank?).uniq

      if values.empty?
        raise ArgumentError, "#{source_label} must contain at least one value"
      end

      values
    end

    def validate_work_modes!(values)
      invalid_modes = values - SUPPORTED_WORK_MODES
      return if invalid_modes.empty?

      raise ArgumentError, "Unsupported work mode(s): #{invalid_modes.join(", ")}. Supported values: #{SUPPORTED_WORK_MODES.join(", ")}"
    end

    def supports_work_mode_filter_for_source?(source:, provider:)
      return false if WORK_MODE_UNSUPPORTED_SOURCES.include?(source)

      provider.discovery_step&.supports_work_mode_filter? != false
    end
  end
end
