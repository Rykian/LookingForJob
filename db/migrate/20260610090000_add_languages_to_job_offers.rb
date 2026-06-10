class AddLanguagesToJobOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :job_offers, :languages, :jsonb, default: [], null: false

    add_index :job_offers, :languages, using: :gin
  end
end
