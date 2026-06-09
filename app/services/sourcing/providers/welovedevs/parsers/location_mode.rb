# frozen_string_literal: true

module Sourcing
  module Providers
    module Welovedevs
      module Parsers
        # Maps a WeLoveDevs offer to a JobOffer location_mode value
        # ("remote" / "hybrid" / "on-site"), most-precise signal first:
        #
        #   1. The per-offer remote chip text (a[href*='/app/job-remote']). This is the
        #      authoritative semantic label and the ONLY signal that separates "Occasional
        #      remote work" (predominantly on-site) from a real hybrid split — the
        #      structured remotePolicy reports "hybrid" frequency for both. Mapping:
        #        "100% Teleworking"                  → remote
        #        "Hybrid teleworking (N weekdays)" / "Regular remote work" → hybrid
        #        "Occasional remote work"            → on-site
        #      Generic "Remote IT jobs" category links match nothing and are ignored.
        #   2. remotePolicy.frequency from the embedded app state — fills in on-site offers,
        #      which render no remote chip (fullTime→remote, hybrid→hybrid, no→on-site).
        #   3. JSON-LD jobLocationType=TELECOMMUTE (full remote only).
        #   4. meta-description text.
        REMOTE_CHIP_SELECTOR = "a[href*='/app/job-remote']"

        class LocationMode
          # "Regular remote work" = frequent-but-partial remote → hybrid.
          HYBRID_PATTERN = /hybrid|hybride|regular remote|t[eé]l[eé]travail r[eé]gulier/i
          REMOTE_PATTERN = /100\s*%|full[-\s]?remote|fully remote|t[eé]l[eé]travail total/i
          # "Occasional"/"punctual" remote = predominantly on-site.
          ONSITE_PATTERN = /occasional|occasionnel|ponctuel|on[-\s]?site|sur site|pr[eé]sentiel|pas de t[eé]l[eé]travail|no teleworking/i

          # Offer's own remotePolicy.frequency = first occurrence in the embedded state
          # (related/similar offers follow). Matches escaped (\") and plain quotes.
          FREQUENCY_REGEXP = /remotePolicy\\?":\\?\{[^}]*?frequency\\?":\\?"(\w+)/

          # Meta-description fallback ("Location: 100% remote working" / "Hybrid remote").
          TEXT_PATTERNS = [
            [/100\s*%?\s*remote|full[-\s]?remote|t[eé]l[eé]travail total/i, "remote"],
            [/hybrid|partial[-\s]?remote|t[eé]l[eé]travail partiel/i,       "hybrid"],
            [/on[-\s]?site|sur site|pr[eé]sentiel|no remote/i,             "on-site"],
          ].freeze

          def self.call(doc:, ld:, text:, html: nil)
            from_chip(doc) ||
              from_frequency(html) ||
              (ld["jobLocationType"].to_s =~ /TELECOMMUTE/i ? "remote" : nil) ||
              from_text(text)
          end

          # Reads the first remote chip whose text matches a specific mode, in document
          # order (the offer's own chip precedes generic category links).
          def self.from_chip(doc)
            return nil unless doc

            doc.css(REMOTE_CHIP_SELECTOR).each do |anchor|
              label = anchor.text.to_s.strip
              next if label.empty?

              return "hybrid"  if label =~ HYBRID_PATTERN
              return "remote"  if label =~ REMOTE_PATTERN
              return "on-site" if label =~ ONSITE_PATTERN
            end
            nil
          end

          def self.from_frequency(html)
            frequency = html.to_s[FREQUENCY_REGEXP, 1]
            return nil unless frequency

            case frequency
            when "fullTime", "full" then "remote"
            when "no", "none"       then "on-site"
            else "hybrid" # hybrid, regular, partial, ...
            end
          end

          def self.from_text(text)
            return nil if text.to_s.empty?

            TEXT_PATTERNS.each { |pattern, value| return value if text =~ pattern }
            nil
          end
        end
      end
    end
  end
end
