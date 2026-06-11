# frozen_string_literal: true

module Sourcing
  module Providers
    module FreeWork
      module Parsers
        # Maps the Free-Work `remoteMode` field to a JobOffer location_mode
        # ("remote" / "hybrid" / "on-site").
        #
        # Live API values (verified 2026-06): full, partial, none, null.
        class LocationMode
          MODE_MAP = {
            "full"    => "remote",
            "partial" => "hybrid",
            "none"    => "on-site",
          }.freeze

          def self.call(remote_mode:)
            MODE_MAP[remote_mode.to_s.downcase]
          end
        end
      end
    end
  end
end
