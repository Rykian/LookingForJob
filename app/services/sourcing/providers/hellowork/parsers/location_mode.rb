# frozen_string_literal: true

module Sourcing
  module Providers
    module Hellowork
      module Parsers
        class LocationMode
          PATTERNS = [
            [/t[ée]l[ée]travail total|100\s*%\s*t[ée]l[ée]travail|full[-_ ]?remote/i, "remote"],
            [/t[ée]l[ée]travail partiel|hybride|occasionnel|\b\d+\s*jours\b/i,        "hybrid"],
            [/sur site|pr[ée]sentiel|on[-_ ]?site/i,                                  "on-site"],
          ].freeze

          def self.call(job_posting:, text_sources:)
            text_sources.compact.each do |raw_text|
              text = Text.normalize(raw_text)
              next if text.nil?

              PATTERNS.each do |pattern, mode|
                return mode if text.match?(pattern)
              end
            end

            return "remote" if job_posting["jobLocationType"].to_s.match?(/TELECOMMUTE/i)

            nil
          end
        end
      end
    end
  end
end
