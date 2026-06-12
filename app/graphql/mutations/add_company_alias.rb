# frozen_string_literal: true

module Mutations
  class AddCompanyAlias < Mutations::BaseMutation
    description "Claim a name as alias of a company, relinking matching offers. Moving a name owned by another company merges it."

    argument :company_id, GraphQL::Types::ID, required: true
    argument :name, String, required: true,
      description: "Raw company name to accept."

    field :company, Types::CompanyType, null: false

    def resolve(company_id:, name:)
      company = Company.find(company_id)
      Companies::AliasManager.new.add_alias!(company: company, name: name)

      { company: company.reload }
    rescue ArgumentError => e
      raise GraphQL::ExecutionError, e.message
    end
  end
end
