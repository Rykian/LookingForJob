module Commute
  class Duration < ApplicationRecord
    self.table_name = "commute_durations"

    FRESHNESS_WINDOW = 30.days

    belongs_to :origin_city,      class_name: "Commute::City", inverse_of: :outbound_durations
    belongs_to :destination_city, class_name: "Commute::City", inverse_of: :inbound_durations

    enum :mode, { driving: "driving", cycling: "cycling", walking: "walking" }, suffix: true

    validates :duration_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :computed_at, presence: true
    # Uniqueness on (origin_city_id, destination_city_id, mode) is enforced by
    # index added in AddCommutePipeline migration.

    scope :fresh, -> { where("computed_at >= ?", FRESHNESS_WINDOW.ago) }

    def fresh?
      return false if computed_at.nil?

      computed_at >= FRESHNESS_WINDOW.ago
    end
  end
end
