# frozen_string_literal: true

module Types
  class SourceCountType < Types::BaseObject
    field :source, String, null: false
    field :count, Integer, null: false
  end
end
