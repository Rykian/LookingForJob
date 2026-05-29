class RenameDiscoveryRunsToRuns < ActiveRecord::Migration[8.1]
  def change
    rename_table :discovery_runs, :runs
    rename_table :discovery_run_job_offers, :run_job_offers
    rename_column :run_job_offers, :discovery_run_id, :run_id
  end
end
