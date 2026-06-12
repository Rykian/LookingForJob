class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.text :description
      t.string :website
      t.boolean :posts_as_recruiter, null: false, default: false
      t.boolean :posts_as_final_client, null: false, default: false
      t.datetime :enriched_at
      t.integer :enrichment_version

      t.timestamps
    end

    create_table :company_aliases do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :normalized_name, null: false

      t.timestamps
    end

    add_index :company_aliases, :normalized_name, unique: true
  end
end
