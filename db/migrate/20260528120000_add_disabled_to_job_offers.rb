class AddDisabledToJobOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :job_offers, :disabled, :boolean, default: false, null: false
  end
end
