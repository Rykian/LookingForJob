class AddScoringAndCityToJobOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :job_offers, :score, :integer
    add_column :job_offers, :score_breakdown, :jsonb
    add_column :job_offers, :scored_at, :datetime
    add_column :job_offers, :city, :string
    add_index :job_offers, :scored_at
    add_index :job_offers, :city
  end
end
