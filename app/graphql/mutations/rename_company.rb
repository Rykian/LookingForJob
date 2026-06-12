# frozen_string_literal: true

module Mutations
  class RenameCompany < Mutations::BaseMutation
    description "Update a company's official name. The new name becomes an alias; renaming to a name owned by another company merges it."

    argument :company_id, GraphQL::Types::ID, required: true
    argument :name, String, required: true

    field :company, Types::CompanyType, null: false

    def resolve(company_id:, name:)
      company = Company.find(company_id)
      Companies::AliasManager.new.rename!(company: company, name: name)

      { company: company.reload }
    rescue ArgumentError => e
      raise GraphQL::ExecutionError, e.message
    end
  end
end
