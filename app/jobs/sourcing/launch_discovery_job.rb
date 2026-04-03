module Sourcing
  class LaunchDiscoveryJob < ApplicationJob
    WORK_MODE_UNSUPPORTED_SOURCES = %w[france_travail].freeze

    def perform(force: false)
      keywords = parse_env_list!("KEYWORDS")
      work_modes = parse_env_list!("WORK_MODE")

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

    def parse_env_list!(key)
      raw_value = ENV[key]

      if raw_value.blank?
        raise ArgumentError, "Missing required environment variable: #{key}"
      end

      values = raw_value.split(",").map(&:strip).reject(&:blank?).uniq

      if values.empty?
        raise ArgumentError, "Environment variable #{key} must contain at least one value"
      end

      values
    end

    def supports_work_mode_filter_for_source?(source:, provider:)
      return false if WORK_MODE_UNSUPPORTED_SOURCES.include?(source)

      provider.discovery_step&.supports_work_mode_filter? != false
    end
  end
end
