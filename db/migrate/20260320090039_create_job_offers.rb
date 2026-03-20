class CreateJobOffers < ActiveRecord::Migration[8.1]
  def change
    create_table :job_offers do |t|
      t.string :source, null: false
      t.string :keyword, null: false
      t.string :work_mode, null: false
      t.string :url, null: false
      t.string :url_hash, null: false
      t.string :job_id
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.text :html_content
      t.datetime :fetched_at
      t.string :title
      t.string :company
      t.string :remote
      t.string :employment_type
      t.text :description_html
      t.integer :salary_min_minor
      t.integer :salary_max_minor
      t.string :salary_currency
      t.datetime :posted_at
      t.integer :hybrid_remote_days_min_per_week
      t.jsonb :primary_technologies
      t.jsonb :secondary_technologies
      t.string :offer_language
      t.string :normalized_seniority
      t.string :english_level_required
      t.datetime :enriched_at

      t.timestamps
    end

    add_index :job_offers, :url, unique: true
    add_index :job_offers, :url_hash, unique: true
    add_index :job_offers, :job_id
    add_index :job_offers, %i[source keyword work_mode]
  end
end
