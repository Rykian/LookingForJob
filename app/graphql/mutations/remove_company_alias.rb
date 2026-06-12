# frozen_string_literal: true

module Mutations
  class RemoveCompanyAlias < Mutations::BaseMutation
    description "Split an alias out of a company: a new company is created with this name and matching offers move to it."

    argument :alias_id, GraphQL::Types::ID, required: true,
      description: "Company alias ID."

    field :original_company, Types::CompanyType, null: false
    field :new_company, Types::CompanyType, null: false

    def resolve(alias_id:)
      company_alias = CompanyAlias.find(alias_id)
      original_company = company_alias.company
      new_company = Companies::AliasManager.new.remove_alias!(company_alias)

      { original_company: original_company.reload, new_company: new_company }
    rescue Companies::AliasManager::OfficialNameAliasError => e
      raise GraphQL::ExecutionError, e.message
    end
  end
end
