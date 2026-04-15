class AddKeywordsAndRejectedToJobOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :job_offers, :keywords, :string, array: true, default: [], null: false
    add_column :job_offers, :rejected, :boolean, default: false, null: false
  end
end
