require "rails_helper"

RSpec.describe "GraphQL query companies", type: :request do
  it "lists companies with pagination and counts" do
    company = Company.find_or_create_by_name!("Acme")
    create_list(:job_offer, 2, company: company)
    create(:job_offer, final_company: company)

    query = <<~GRAPHQL
      query Companies {
        companies(page: 1, perPage: 10) {
          totalCount
          totalPages
          nodes {
            id
            name
            postsAsRecruiter
            postsAsFinalClient
            offerCount
            finalClientOfferCount
          }
        }
      }
    GRAPHQL

    result = post_graphql(query: query)

    expect(result["errors"]).to be_nil
    data = result.dig("data", "companies")
    expect(data["totalCount"]).to eq(1)
    node = data["nodes"].first
    expect(node["name"]).to eq("Acme")
    expect(node["offerCount"]).to eq(2)
    expect(node["finalClientOfferCount"]).to eq(1)
  end

  it "filters by recruiter/final-client flags" do
    Company.find_or_create_by_name!("Recruiter Co").update!(posts_as_recruiter: true)
    Company.find_or_create_by_name!("Employer Co").update!(posts_as_final_client: true)

    query = <<~GRAPHQL
      query Companies($postsAsRecruiter: Boolean) {
        companies(page: 1, perPage: 10, postsAsRecruiter: $postsAsRecruiter) {
          nodes { name }
        }
      }
    GRAPHQL

    result = post_graphql(query: query, variables: { postsAsRecruiter: true })

    names = result.dig("data", "companies", "nodes").map { |n| n["name"] }
    expect(names).to eq(["Recruiter Co"])
  end

  it "sorts by offers_count" do
    busy = Company.find_or_create_by_name!("Busy")
    Company.find_or_create_by_name!("Quiet")
    create_list(:job_offer, 2, company: busy)

    query = <<~GRAPHQL
      query Companies {
        companies(page: 1, perPage: 10, sortBy: "offers_count", sortDirection: "desc") {
          nodes { name }
        }
      }
    GRAPHQL

    result = post_graphql(query: query)

    expect(result.dig("data", "companies", "nodes").map { |n| n["name"] }).to eq(%w[Busy Quiet])
  end

  it "fetches a single company with aliases and technologies" do
    company = Company.find_or_create_by_name!("Acme")
    company.aliases.create!(name: "Acme France")
    create(:job_offer, company: company, primary_technologies: %w[Ruby])

    query = <<~GRAPHQL
      query Company($id: ID!) {
        company(id: $id) {
          name
          aliases { name }
          topTechnologies
        }
      }
    GRAPHQL

    result = post_graphql(query: query, variables: { id: company.id })

    data = result.dig("data", "company")
    expect(data["name"]).to eq("Acme")
    expect(data["aliases"].map { |a| a["name"] }).to contain_exactly("Acme", "Acme France")
    expect(data["topTechnologies"]).to eq(["Ruby"])
  end

  it "previews alias impact" do
    company = Company.find_or_create_by_name!("Acme")
    create(:job_offer, company_name: "Acme SAS", normalized_company_name: "acme")

    query = <<~GRAPHQL
      query Preview($name: String!) {
        companyAliasPreview(name: $name) {
          normalizedName
          matchedOffersCount
          owningCompany { id }
        }
      }
    GRAPHQL

    result = post_graphql(query: query, variables: { name: "Acme SAS" })

    data = result.dig("data", "companyAliasPreview")
    expect(data["normalizedName"]).to eq("acme")
    expect(data["matchedOffersCount"]).to eq(1)
    expect(data.dig("owningCompany", "id")).to eq(company.id.to_s)
  end
end
