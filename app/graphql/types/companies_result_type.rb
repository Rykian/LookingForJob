# frozen_string_literal: true

module Types
  class CompaniesResultType < Types::BaseObject
    description "Paginated response for companies."

    field :nodes, [Types::CompanyType], null: false,
      description: "Companies for the requested page."
    field :total_count, Integer, null: false,
      description: "Total number of companies matching current filters."
    field :total_pages, Integer, null: false,
      description: "Total pages with current per_page value."
  end
end
