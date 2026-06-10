# Must run via db:migrate:with_data so the languages backfill data migration
# (20260610090100) executes before this column is dropped.
class RemoveEnglishLevelRequiredFromJobOffers < ActiveRecord::Migration[8.1]
  def change
    remove_column :job_offers, :english_level_required, :string
  end
end
