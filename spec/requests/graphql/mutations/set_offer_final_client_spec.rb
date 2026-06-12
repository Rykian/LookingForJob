require "rails_helper"

RSpec.describe "GraphQL mutation setOfferFinalClient", type: :request do
  let(:mutation) do
    <<~GRAPHQL
      mutation SetOfferFinalClient($offerId: ID!, $companyName: String) {
        setOfferFinalClient(input: { offerId: $offerId, companyName: $companyName }) {
          jobOffer {
            id
            finalCompany { id name postsAsFinalClient }
          }
        }
      }
    GRAPHQL
  end

  it "links the named company as final client, creating it when needed" do
    offer = create(:job_offer)

    result = post_graphql(query: mutation, variables: { offerId: offer.id, companyName: "Globex" })

    expect(result["errors"]).to be_nil
    final = result.dig("data", "setOfferFinalClient", "jobOffer", "finalCompany")
    expect(final["name"]).to eq("Globex")
    expect(final["postsAsFinalClient"]).to be(true)
    expect(offer.reload.final_company.name).to eq("Globex")
  end

  it "resolves existing companies through aliases" do
    company = Company.find_or_create_by_name!("Globex")
    company.aliases.create!(name: "Globex France")
    offer = create(:job_offer)

    post_graphql(query: mutation, variables: { offerId: offer.id, companyName: "globex france" })

    expect(offer.reload.final_company).to eq(company)
  end

  it "clears the final client when no name is given" do
    company = Company.find_or_create_by_name!("Globex")
    offer = create(:job_offer, final_company: company)

    result = post_graphql(query: mutation, variables: { offerId: offer.id, companyName: nil })

    expect(result["errors"]).to be_nil
    expect(offer.reload.final_company).to be_nil
  end
end
