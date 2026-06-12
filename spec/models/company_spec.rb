require "rails_helper"

RSpec.describe Company do
  describe ".normalize" do
    it "transliterates accents and lowercases" do
      expect(described_class.normalize("Société Générale")).to eq("societe generale")
    end

    it "strips legal suffixes at the end" do
      expect(described_class.normalize("Acme SAS")).to eq("acme")
      expect(described_class.normalize("Acme SASU")).to eq("acme")
      expect(described_class.normalize("Acme Groupe")).to eq("acme")
    end

    it "strips stacked legal suffixes" do
      expect(described_class.normalize("Acme Group SA")).to eq("acme")
    end

    it "keeps suffix-like words in the middle of the name" do
      expect(described_class.normalize("SA Solutions")).to eq("sa solutions")
    end

    it "returns empty string for blank input" do
      expect(described_class.normalize(nil)).to eq("")
      expect(described_class.normalize("  ")).to eq("")
    end
  end

  describe ".find_or_create_by_name!" do
    it "creates a company with an alias for its own name" do
      company = described_class.find_or_create_by_name!("Acme SAS")

      expect(company.name).to eq("Acme SAS")
      expect(company.aliases.pluck(:normalized_name)).to eq(["acme"])
    end

    it "resolves an existing company through any of its aliases" do
      company = described_class.find_or_create_by_name!("Acme SAS")
      company.aliases.create!(name: "Acme France")

      expect(described_class.find_or_create_by_name!("acme france")).to eq(company)
      expect(described_class.find_or_create_by_name!("ACME")).to eq(company)
    end

    it "keeps suffix-only names intact (a company can be literally named SAS)" do
      expect(described_class.find_or_create_by_name!("SAS").name).to eq("SAS")
    end

    it "returns nil when the name normalizes to blank" do
      expect(described_class.find_or_create_by_name!("!!!")).to be_nil
    end
  end

  describe "#top_technologies" do
    let(:company) { create(:company) }

    it "aggregates technologies from final-client offers only" do
      create(:job_offer, company: company, posted_by_recruiter: false,
                         primary_technologies: %w[Ruby], secondary_technologies: %w[Redis])
      create(:job_offer, final_company: company,
                         primary_technologies: %w[Ruby PostgreSQL])
      # Recruiter-posted offer: techs belong to the client, not this company.
      create(:job_offer, company: company, posted_by_recruiter: true,
                         primary_technologies: %w[COBOL])

      expect(company.top_technologies).to eq(%w[Ruby PostgreSQL Redis])
    end

    it "respects the limit" do
      create(:job_offer, company: company, primary_technologies: %w[A B C])

      expect(company.top_technologies(limit: 2).size).to eq(2)
    end
  end
end
