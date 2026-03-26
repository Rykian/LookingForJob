class RenameRemoteToLocationMode < ActiveRecord::Migration[8.1]
  def up
    # First, we need to convert the enum values
    # "yes" => "remote", "hybrid" => "hybrid", "no" => "on-site"
    execute <<-SQL
      UPDATE job_offers SET remote = CASE
        WHEN remote = 'yes' THEN 'remote'
        WHEN remote = 'no' THEN 'on-site'
        WHEN remote = 'hybrid' THEN 'hybrid'
      END
      WHERE remote IS NOT NULL;
    SQL

    # Rename the column
    rename_column :job_offers, :remote, :location_mode
  end

  def down
    # Rename back
    rename_column :job_offers, :location_mode, :remote

    # Convert back to old values
    execute <<-SQL
      UPDATE job_offers SET remote = CASE
        WHEN remote = 'remote' THEN 'yes'
        WHEN remote = 'on-site' THEN 'no'
        WHEN remote = 'hybrid' THEN 'hybrid'
      END
      WHERE remote IS NOT NULL;
    SQL
  end
end
