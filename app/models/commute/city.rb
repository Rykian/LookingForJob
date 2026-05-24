module Commute
  class City < ApplicationRecord
    self.table_name = "commute_cities"

    has_many :outbound_durations,
             class_name: "Commute::Duration",
             foreign_key: :origin_city_id,
             dependent: :destroy,
             inverse_of: :origin_city
    has_many :inbound_durations,
             class_name: "Commute::Duration",
             foreign_key: :destination_city_id,
             dependent: :destroy,
             inverse_of: :destination_city
    has_many :job_offers, foreign_key: :commute_city_id, dependent: :nullify, inverse_of: :commute_city

    validates :name, :normalized_name, presence: true
    # Uniqueness is enforced by the DB unique index on normalized_name. A Rails
    # `validates :uniqueness` here would race under concurrent CommuteJobs and
    # raise RecordInvalid before create_or_find_by! could retry on RecordNotUnique.

    def self.normalize(raw)
      ActiveSupport::Inflector.transliterate(raw.to_s).downcase.strip
    end
  end
end
