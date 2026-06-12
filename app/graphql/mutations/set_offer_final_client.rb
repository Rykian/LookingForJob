# frozen_string_literal: true

module Mutations
  class SetOfferFinalClient < Mutations::BaseMutation
    description "Manually set (or clear) the final client behind an offer. Accepts any name: a stored guess or free text."

    argument :offer_id, GraphQL::Types::ID, required: true,
      description: "Job offer ID."
    argument :company_name, String, required: false,
      description: "Final client company name. Omit or null to clear the link."

    field :job_offer, Types::JobOfferType, null: false

    def resolve(offer_id:, company_name: nil)
      offer = JobOffer.find(offer_id)

      if company_name.blank?
        offer.update!(final_company: nil)
      else
        company = Company.find_or_create_by_name!(company_name)
        company.update!(posts_as_final_client: true) unless company.posts_as_final_client
        offer.update!(final_company: company)
      end

      { job_offer: offer }
    end
  end
end
