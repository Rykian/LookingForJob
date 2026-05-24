class AddCommutePipeline < ActiveRecord::Migration[8.1]
  def up
    create_table :commute_cities do |t|
      t.string   :name,            null: false
      t.string   :normalized_name, null: false
      t.decimal  :latitude,  precision: 9, scale: 6
      t.decimal  :longitude, precision: 9, scale: 6
      t.datetime :geocoded_at
      t.timestamps
    end
    add_index :commute_cities, :normalized_name, unique: true

    create_table :commute_durations do |t|
      t.references :origin_city,      null: false, foreign_key: { to_table: :commute_cities }
      t.references :destination_city, null: false, foreign_key: { to_table: :commute_cities }
      t.string   :mode,             null: false
      t.integer  :duration_minutes, null: false
      t.datetime :computed_at,      null: false
      t.timestamps
    end
    add_index :commute_durations,
              [:origin_city_id, :destination_city_id, :mode],
              unique: true

    add_reference :job_offers, :commute_city,
                  foreign_key: { to_table: :commute_cities }, null: true

    JobOffer.reset_column_information
    JobOffer.find_each do |offer|
      Sourcing::CommuteJob.perform_later(offer.id, "enrich", source: offer.source, force: true)
    end
  end

  def down
    remove_reference :job_offers, :commute_city, foreign_key: { to_table: :commute_cities }
    drop_table :commute_durations
    drop_table :commute_cities
  end
end
