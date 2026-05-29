class CreateDiscoveryRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :discovery_runs do |t|
      t.string :keywords,   array: true, default: [], null: false
      t.string :providers,  array: true, default: [], null: false
      t.string :work_modes, array: true, default: [], null: false
      t.timestamps
    end

    create_table :discovery_run_job_offers do |t|
      t.references :discovery_run, null: false, foreign_key: true
      t.references :job_offer,     null: false, foreign_key: true
    end

    add_index :discovery_run_job_offers, [:discovery_run_id, :job_offer_id], unique: true
  end
end
