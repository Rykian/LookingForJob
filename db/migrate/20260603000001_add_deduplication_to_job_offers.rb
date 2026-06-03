class AddDeduplicationToJobOffers < ActiveRecord::Migration[8.1]
  def change
    add_column :job_offers, :canonical_id, :bigint, null: true
    add_column :job_offers, :content_fingerprint, :string, null: true

    add_index :job_offers, :canonical_id
    add_index :job_offers, :content_fingerprint

    add_foreign_key :job_offers, :job_offers, column: :canonical_id, on_delete: :nullify
  end
end
