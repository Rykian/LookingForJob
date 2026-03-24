class AddStepsDetailsExpandToJobOffers < ActiveRecord::Migration[8.1]
  def up
    add_column :job_offers, :steps_details, :jsonb, default: {}, null: false

    execute(<<~SQL)
      UPDATE job_offers
      SET steps_details = (
          CASE WHEN first_seen_at IS NOT NULL
            THEN jsonb_build_object('discovery', jsonb_build_object('at', to_json(first_seen_at)#>>'{}', 'version', 1))
            ELSE '{}'::jsonb
          END
          ||
          CASE WHEN fetched_at IS NOT NULL
            THEN jsonb_build_object('fetch', jsonb_build_object('at', to_json(fetched_at)#>>'{}', 'version', 1))
            ELSE '{}'::jsonb
          END
          ||
          CASE WHEN enriched_at IS NOT NULL
            THEN jsonb_build_object('enrich', jsonb_build_object('at', to_json(enriched_at)#>>'{}', 'version', 1))
            ELSE '{}'::jsonb
          END
          ||
          CASE WHEN scored_at IS NOT NULL
            THEN jsonb_build_object('score', jsonb_build_object('at', to_json(scored_at)#>>'{}', 'version', 1))
            ELSE '{}'::jsonb
          END
      )
      WHERE first_seen_at IS NOT NULL
         OR fetched_at IS NOT NULL
         OR enriched_at IS NOT NULL
         OR scored_at IS NOT NULL
    SQL

    remove_index :job_offers, name: "index_job_offers_on_scored_at", if_exists: true
    remove_column :job_offers, :first_seen_at
    remove_column :job_offers, :fetched_at
    remove_column :job_offers, :enriched_at
    remove_column :job_offers, :scored_at
  end

  def down
    add_column :job_offers, :first_seen_at, :datetime
    add_column :job_offers, :fetched_at, :datetime
    add_column :job_offers, :enriched_at, :datetime
    add_column :job_offers, :scored_at, :datetime

    execute <<~SQL
      UPDATE job_offers
      SET
        first_seen_at = (steps_details->'discovery'->>'at')::timestamptz,
        fetched_at    = (steps_details->'fetch'->>'at')::timestamptz,
        enriched_at   = (steps_details->'enrich'->>'at')::timestamptz,
        scored_at     = (steps_details->'score'->>'at')::timestamptz
    SQL

    add_index :job_offers, :scored_at
    remove_column :job_offers, :steps_details
  end
end