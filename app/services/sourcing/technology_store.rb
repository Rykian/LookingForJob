require "json"

module Sourcing
  # Redis-backed storage for the technology canonicalization artifacts produced
  # by CanonicalizeTechnologiesJob: the raw->canonical alias map and the list of the
  # most-used technologies. Stored in Redis (not the filesystem) so they are
  # visible to every process — the job writes them on one worker, while the
  # enrich step and GraphQL API read them from the web/other worker processes.
  # No TTL: these are durable until the next dedup run overwrites them.
  class TechnologyStore
    ALIAS_MAP_KEY = "sourcing:technologies:alias_map".freeze
    COMMON_KEY = "sourcing:technologies:common".freeze

    class << self
      def write_alias_map(alias_map)
        write(ALIAS_MAP_KEY, alias_map)
      end

      # Raw->canonical mapping; {} when no dedup run has completed yet.
      def read_alias_map
        read(ALIAS_MAP_KEY) || {}
      end

      def write_common_technologies(names)
        write(COMMON_KEY, names)
      end

      # Most-used canonical technology names; [] before the first dedup run.
      def read_common_technologies
        read(COMMON_KEY) || []
      end

      private

      def write(key, value)
        Sidekiq.redis { |r| r.set(key, JSON.generate(value)) }
      end

      def read(key)
        raw = Sidekiq.redis { |r| r.get(key) }
        raw && JSON.parse(raw)
      end
    end
  end
end
