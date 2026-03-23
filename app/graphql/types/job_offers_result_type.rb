# frozen_string_literal: true

module Types
  class JobOffersResultType < Types::BaseObject
    description "Paginated response for job offers."

    field :nodes, [Types::JobOfferType], null: false,
      description: "Offers for the requested page."
    field :total_count, Integer, null: false,
      description: "Total number of offers matching current filters."
    field :total_pages, Integer, null: false,
      description: "Total pages with current per_page value."
  end
end
