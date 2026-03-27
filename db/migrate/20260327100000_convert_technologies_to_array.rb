class ConvertTechnologiesToArray < ActiveRecord::Migration[7.1]
  def up
    # Add new array columns
    add_column :job_offers, :primary_technologies_tmp, :string, array: true, default: [], null: false
    add_column :job_offers, :secondary_technologies_tmp, :string, array: true, default: [], null: false

    # Copy and normalize data from jsonb to array
    execute <<-SQL.squish
      UPDATE job_offers
      SET primary_technologies_tmp = COALESCE((
        SELECT ARRAY_AGG(elem::text)
        FROM jsonb_array_elements_text(primary_technologies) AS elem
      ), ARRAY[]::text[]),
      secondary_technologies_tmp = COALESCE((
        SELECT ARRAY_AGG(elem::text)
        FROM jsonb_array_elements_text(secondary_technologies) AS elem
      ), ARRAY[]::text[])
    SQL

    # Remove old columns and rename new ones
    remove_column :job_offers, :primary_technologies, :jsonb
    remove_column :job_offers, :secondary_technologies, :jsonb
    rename_column :job_offers, :primary_technologies_tmp, :primary_technologies
    rename_column :job_offers, :secondary_technologies_tmp, :secondary_technologies
  end

  def down
    # Add jsonb columns back
    add_column :job_offers, :primary_technologies_tmp, :jsonb, default: [], null: false
    add_column :job_offers, :secondary_technologies_tmp, :jsonb, default: [], null: false

    # Copy data from array to jsonb
    execute <<-SQL.squish
      UPDATE job_offers
      SET primary_technologies_tmp = to_jsonb(primary_technologies),
          secondary_technologies_tmp = to_jsonb(secondary_technologies)
    SQL

    remove_column :job_offers, :primary_technologies, :string, array: true
    remove_column :job_offers, :secondary_technologies, :string, array: true
    rename_column :job_offers, :primary_technologies_tmp, :primary_technologies
    rename_column :job_offers, :secondary_technologies_tmp, :secondary_technologies
  end
end
