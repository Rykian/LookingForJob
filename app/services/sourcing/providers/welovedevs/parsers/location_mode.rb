# frozen_string_literal: true

module Sourcing
  module Providers
    module Welovedevs
      module Parsers
        # Maps a WeLoveDevs `details.remotePolicy` object to a JobOffer location_mode value
        # ("remote" / "hybrid" / "on-site").
        #
        # `frequency` is the authoritative signal: `fullTime` → fully remote, `hybrid`
        # (and any partial variant) → hybrid, `no`/`none` → on-site. A missing policy
        # yields nil (enrich falls back to the description).
        class LocationMode
          def self.call(remote_policy:)
            return nil unless remote_policy.is_a?(Hash)

            case remote_policy["frequency"].to_s
            when "fullTime", "full" then "remote"
            when "no", "none", ""    then on_site_or_nil(remote_policy)
            else "hybrid"
            end
          end

          # Distinguishes an explicit no-remote policy ("no"/"none") from a policy object
          # that simply omits frequency (nil).
          def self.on_site_or_nil(remote_policy)
            remote_policy.key?("frequency") && !remote_policy["frequency"].to_s.empty? ? "on-site" : nil
          end
          private_class_method :on_site_or_nil
        end
      end
    end
  end
end
