# frozen_string_literal: true

class BackfillCompanies < ActiveRecord::Migration[8.1]
  # Deterministic, no-LLM pass: normalize company names, create companies with
  # their own-name alias, link offers. Classification and enrichment arrive
  # through the pipeline as active offers are re-discovered (the missing
  # "company" step triggers Sourcing::CompanyJob, which enqueues
  # Companies::EnrichmentJob for new companies).
  def up
    JobOffer.where(normalized_company_name: nil).where.not(company_name: [nil, ""]).find_each do |offer|
      offer.update_column(:normalized_company_name, Company.normalize(offer.company_name).presence)
    end

    JobOffer.where.not(normalized_company_name: nil).distinct.pluck(:normalized_company_name).each do |normalized|
      raw_name = JobOffer.where(normalized_company_name: normalized).where.not(company_name: nil).pick(:company_name)
      company = Company.find_or_create_by_name!(raw_name)
      next unless company

      JobOffer.where(normalized_company_name: normalized)
              .where("company_id IS DISTINCT FROM ?", company.id)
              .update_all(company_id: company.id, updated_at: Time.current)
    end
  end

  def down; end
end
