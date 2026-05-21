class AddJobOfferQueryIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :job_offers, :source
    add_index :job_offers, :location_mode
    add_index :job_offers, :last_seen_at
    add_index :job_offers, :score
    add_index :job_offers,
      "((steps_details->'discovery'->>'at'))",
      name: "index_job_offers_on_discovery_at"
  end
end
