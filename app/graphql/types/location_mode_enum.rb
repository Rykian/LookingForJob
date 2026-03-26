# frozen_string_literal: true

module Types
  class LocationModeEnum < Types::BaseEnum
    value "REMOTE", value: "remote", description: "Fully remote position"
    value "HYBRID", value: "hybrid", description: "Hybrid work (mix of remote and in-office)"
    value "ON_SITE", value: "on-site", description: "On-site / in-office position"
  end
end
