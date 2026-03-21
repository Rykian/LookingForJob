module Sourcing
  class LaunchDiscoveryJob < ApplicationJob
    def perform
      keywords = parse_env_list!("KEYWORDS")
      work_modes = parse_env_list!("WORK_MODE")

      Sourcing::Providers.registry.sources.each do |source|
        keywords.each do |keyword|
          work_modes.each do |work_mode|
            DiscoveryJob.perform_later(
              source: source,
              keyword: keyword,
              work_mode: work_mode,
              page: 1
            )
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
  end
end
