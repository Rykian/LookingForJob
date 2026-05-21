# frozen_string_literal: true

module Types
  module Queries
    module JobOffer
      extend ActiveSupport::Concern

      included do
        field :job_offer, Types::JobOfferType, null: true,
          description: "Find a single job offer by ID." do
          argument :id, GraphQL::Types::ID, required: true, description: "Job offer ID."
        end
      end

      def job_offer(id:)
        ::JobOffer.where(rejected: false).find_by(id: id)
      end
    end
  end
end
