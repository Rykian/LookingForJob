# frozen_string_literal: true

module Sourcing
  module Providers
    module Linkedin
      module Parsers
        # Converts LinkedIn's relative posted-time labels into an absolute ISO8601 timestamp
        # anchored at the current time. LinkedIn guest pages do not expose absolute dates.
        #
        # Recognized forms:
        #   "just now", "X minutes ago", "X hours ago", "X days ago",
        #   "X weeks ago", "X months ago", "X years ago"
        # Returns nil for unrecognized input.
        class PostedAt
          def self.call(raw, now: Time.now)
            return nil if raw.nil?

            text = raw.to_s.strip.downcase
            return nil if text.empty?

            case text
            when /\Ajust\s+now\z/, /\Aa\s+moment\s+ago\z/
              now.utc.iso8601
            when /\A(\d+)\s+minute/
              (now - Regexp.last_match(1).to_i * 60).utc.iso8601
            when /\A(\d+)\s+hour/
              (now - Regexp.last_match(1).to_i * 3_600).utc.iso8601
            when /\A(\d+)\s+day/
              (now - Regexp.last_match(1).to_i * 86_400).utc.iso8601
            when /\A(\d+)\s+week/
              (now - Regexp.last_match(1).to_i * 7 * 86_400).utc.iso8601
            when /\A(\d+)\s+month/
              # Approximate: 30 days. LinkedIn relative dates are coarse anyway.
              (now - Regexp.last_match(1).to_i * 30 * 86_400).utc.iso8601
            when /\A(\d+)\s+year/
              (now - Regexp.last_match(1).to_i * 365 * 86_400).utc.iso8601
            end
          end
        end
      end
    end
  end
end
