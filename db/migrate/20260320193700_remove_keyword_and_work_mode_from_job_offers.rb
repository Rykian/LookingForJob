class RemoveKeywordAndWorkModeFromJobOffers < ActiveRecord::Migration[8.1]
  def change
    remove_column :job_offers, :keyword, :string
    remove_column :job_offers, :work_mode, :string
    remove_column :job_offers, :job_id, :string
  end
end
