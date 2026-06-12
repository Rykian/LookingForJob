require "rails_helper"

RSpec.describe Companies::AliasManager do
  include ActiveJob::TestHelper

  subject(:manager) { described_class.new }

  describe "#preview" do
    it "returns normalized name, matched offers and owning company" do
      company = Company.find_or_create_by_name!("Acme")
      create(:job_offer, company_name: "Acme SAS", normalized_company_name: "acme")
      create(:job_offer, company_name: "Other", normalized_company_name: "other")

      preview = manager.preview("Acme SAS")

      expect(preview.normalized_name).to eq("acme")
      expect(preview.matched_offers_count).to eq(1)
      expect(preview.owning_company).to eq(company)
    end

    it "returns nil owning company for unknown names" do
      expect(manager.preview("Nobody").owning_company).to be_nil
    end
  end

  describe "#add_alias!" do
    it "creates the alias and relinks matching offers" do
      company = Company.find_or_create_by_name!("Acme")
      offer = create(:job_offer, company_name: "Acme France", normalized_company_name: "acme france")

      manager.add_alias!(company: company, name: "Acme France")

      expect(company.aliases.pluck(:normalized_name)).to contain_exactly("acme", "acme france")
      expect(offer.reload.company_id).to eq(company.id)
    end

    it "moves an alias from another company and deletes the emptied donor" do
      company = Company.find_or_create_by_name!("Acme")
      donor = Company.find_or_create_by_name!("Acme France")
      offer = create(:job_offer, company: donor, company_name: "Acme France", normalized_company_name: "acme france")

      manager.add_alias!(company: company, name: "Acme France")

      expect(offer.reload.company_id).to eq(company.id)
      expect(Company.exists?(donor.id)).to be(false)
      expect(company.aliases.pluck(:normalized_name)).to contain_exactly("acme", "acme france")
    end

    it "keeps a donor that still has other aliases" do
      company = Company.find_or_create_by_name!("Acme")
      donor = Company.find_or_create_by_name!("Globex")
      donor.aliases.create!(name: "Globex France")

      manager.add_alias!(company: company, name: "Globex France")

      expect(Company.exists?(donor.id)).to be(true)
      expect(donor.aliases.pluck(:normalized_name)).to eq(["globex"])
    end

    it "rejects names that normalize to blank" do
      company = Company.find_or_create_by_name!("Acme")

      expect { manager.add_alias!(company: company, name: "!!!") }.to raise_error(ArgumentError)
    end
  end

  describe "#remove_alias!" do
    it "splits the alias into a new company and relinks matching offers" do
      company = Company.find_or_create_by_name!("Acme")
      company_alias = company.aliases.create!(name: "Acme France")
      offer = create(:job_offer, company: company, company_name: "Acme France", normalized_company_name: "acme france")

      new_company = nil
      perform_enqueued_jobs_check = -> { new_company = manager.remove_alias!(company_alias) }
      assert_enqueued_with(job: Companies::EnrichmentJob) { perform_enqueued_jobs_check.call }

      expect(new_company.name).to eq("Acme France")
      expect(new_company).not_to eq(company)
      expect(company_alias.reload.company).to eq(new_company)
      expect(offer.reload.company_id).to eq(new_company.id)
    end

    it "refuses to remove the alias matching the official name" do
      company = Company.find_or_create_by_name!("Acme")

      expect { manager.remove_alias!(company.aliases.first) }
        .to raise_error(Companies::AliasManager::OfficialNameAliasError)
    end
  end

  describe "#rename!" do
    it "updates the official name and ensures an alias exists" do
      company = Company.find_or_create_by_name!("Acme")

      manager.rename!(company: company, name: "Acme Corporation")

      expect(company.reload.name).to eq("Acme Corporation")
      expect(company.aliases.pluck(:normalized_name)).to contain_exactly("acme", "acme corporation")
    end

    it "merges when renaming to a name owned by another company" do
      company = Company.find_or_create_by_name!("Acme")
      other = Company.find_or_create_by_name!("Globex")

      manager.rename!(company: company, name: "Globex")

      expect(company.reload.name).to eq("Globex")
      expect(Company.exists?(other.id)).to be(false)
    end

    it "rejects blank names" do
      company = Company.find_or_create_by_name!("Acme")

      expect { manager.rename!(company: company, name: "  ") }.to raise_error(ArgumentError)
    end
  end
end
