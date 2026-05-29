# frozen_string_literal: true

module Types
  class PipelineErrorsResultType < Types::BaseObject
    description "Paginated response for pipeline errors."

    field :nodes, [Types::PipelineErrorType], null: false,
      description: "Errors for the requested page."
    field :total_count, Integer, null: false,
      description: "Total number of errors matching current filters."
    field :total_pages, Integer, null: false,
      description: "Total pages with current per_page value."
  end
end
