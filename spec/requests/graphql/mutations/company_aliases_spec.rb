require "rails_helper"

RSpec.describe "GraphQL company alias mutations", type: :request do
  describe "addCompanyAlias" do
    let(:mutation) do
      <<~GRAPHQL
        mutation AddCompanyAlias($companyId: ID!, $name: String!) {
          addCompanyAlias(input: { companyId: $companyId, name: $name }) {
            company {
              id
              aliases { name }
            }
          }
        }
      GRAPHQL
    end

    it "adds the alias and relinks matching offers" do
      company = Company.find_or_create_by_name!("Acme")
      offer = create(:job_offer, company_name: "Acme France", normalized_company_name: "acme france")

      result = post_graphql(query: mutation, variables: { companyId: company.id, name: "Acme France" })

      expect(result["errors"]).to be_nil
      names = result.dig("data", "addCompanyAlias", "company", "aliases").map { |a| a["name"] }
      expect(names).to contain_exactly("Acme", "Acme France")
      expect(offer.reload.company_id).to eq(company.id)
    end

    it "returns an error for blank-normalizing names" do
      company = Company.find_or_create_by_name!("Acme")

      result = post_graphql(query: mutation, variables: { companyId: company.id, name: "!!!" })

      expect(result["errors"]).to be_present
    end
  end

  describe "removeCompanyAlias" do
    let(:mutation) do
      <<~GRAPHQL
        mutation RemoveCompanyAlias($aliasId: ID!) {
          removeCompanyAlias(input: { aliasId: $aliasId }) {
            originalCompany { id }
            newCompany { id name }
          }
        }
      GRAPHQL
    end

    it "splits the alias into a new company" do
      company = Company.find_or_create_by_name!("Acme")
      company_alias = company.aliases.create!(name: "Acme France")

      result = post_graphql(query: mutation, variables: { aliasId: company_alias.id })

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "removeCompanyAlias", "newCompany", "name")).to eq("Acme France")
    end

    it "refuses to remove the official-name alias" do
      company = Company.find_or_create_by_name!("Acme")

      result = post_graphql(query: mutation, variables: { aliasId: company.aliases.first.id })

      expect(result["errors"]).to be_present
    end
  end

  describe "renameCompany" do
    let(:mutation) do
      <<~GRAPHQL
        mutation RenameCompany($companyId: ID!, $name: String!) {
          renameCompany(input: { companyId: $companyId, name: $name }) {
            company { name }
          }
        }
      GRAPHQL
    end

    it "updates the official name" do
      company = Company.find_or_create_by_name!("Acme")

      result = post_graphql(query: mutation, variables: { companyId: company.id, name: "Acme Corp" })

      expect(result["errors"]).to be_nil
      expect(result.dig("data", "renameCompany", "company", "name")).to eq("Acme Corp")
    end
  end
end
