class AddCompanyToJobOffers < ActiveRecord::Migration[8.1]
  def change
    rename_column :job_offers, :company, :company_name

    add_column :job_offers, :normalized_company_name, :string
    add_index :job_offers, :normalized_company_name

    add_reference :job_offers, :company, foreign_key: true
    add_reference :job_offers, :final_company, foreign_key: { to_table: :companies }

    add_column :job_offers, :posted_by_recruiter, :boolean
    add_column :job_offers, :final_client_guesses, :jsonb, null: false, default: []
  end
end
