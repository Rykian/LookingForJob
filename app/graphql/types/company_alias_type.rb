# frozen_string_literal: true

module Types
  class CompanyAliasType < Types::BaseObject
    description "An accepted name under which a company posts offers."

    field :id, ID, null: false
    field :name, String, null: false
  end
end
