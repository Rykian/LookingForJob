# frozen_string_literal: true

class BackfillLanguagesFromEnglishLevel < ActiveRecord::Migration[8.1]
  def up
    # Deterministic backfill from the legacy column. Old "none" maps to [] —
    # the legacy vocabulary cannot distinguish "mentioned but optional" from
    # "absent". Multi-language data arrives as offers get re-enriched: the
    # enrich step VERSION bump makes the pipeline re-run enrichment whenever
    # an offer is re-discovered.
    execute(<<~SQL.squish)
      UPDATE job_offers
      SET languages = CASE
        WHEN english_level_required IN ('basic', 'professional', 'fluent')
          THEN jsonb_build_array(jsonb_build_object('language', 'en', 'level', english_level_required))
        ELSE '[]'::jsonb
      END
    SQL
  end

  def down; end
end
