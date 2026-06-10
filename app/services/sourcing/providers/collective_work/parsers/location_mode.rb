# frozen_string_literal: true

module Sourcing
  module Providers
    module CollectiveWork
      module Parsers
        # Maps Collective.work `workPreferences` array to a JobOffer location_mode
        # ("remote" / "hybrid" / "on-site").
        #
        # Each project carries an array (the recruiter can accept multiple modes — e.g.
        # ["HYBRID", "ON_SITE"] means hybrid OR fully on-site). We collapse the array
        # into the single most-flexible mode the recruiter accepts, ordered:
        #   REMOTE > HYBRID > ON_SITE
        # An offer tagged ["HYBRID", "ON_SITE"] is reported as "hybrid" because the
        # recruiter accepts hybrid candidates; a candidate filter for "remote" should
        # not catch it, but a "hybrid" filter should.
        class LocationMode
          MODE_MAP = {
            "REMOTE"  => "remote",
            "HYBRID"  => "hybrid",
            "ON_SITE" => "on-site",
            "ONSITE"  => "on-site",
          }.freeze

          PRIORITY = %w[remote hybrid on-site].freeze

          def self.call(work_preferences:)
            modes = Array(work_preferences).filter_map { |pref| MODE_MAP[pref.to_s.upcase] }
            return nil if modes.empty?

            PRIORITY.find { |mode| modes.include?(mode) }
          end
        end
      end
    end
  end
end
