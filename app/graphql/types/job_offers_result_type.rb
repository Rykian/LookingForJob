# frozen_string_literal: true

module Types
  class JobOffersResultType < Types::BaseObject
    field :nodes, [Types::JobOfferType], null: false
    field :total_count, Integer, null: false
    field :total_pages, Integer, null: false
  end
end
