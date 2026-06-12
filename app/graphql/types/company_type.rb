# frozen_string_literal: true

module Types
  class CompanyType < Types::BaseObject
    # Batches per-company offer counts into a single SQL query. The column
    # selects the role: :company_id (posted offers) or :final_company_id
    # (offers where the company is the linked final client).
    class OfferCounts < GraphQL::Dataloader::Source
      def initialize(column)
        @column = column
      end

      def fetch(company_ids)
        rows = ::JobOffer.where(@column => company_ids).group(@column).count
        company_ids.map { |id| rows[id] || 0 }
      end
    end

    field :id, ID, null: false
    field :name, String, null: false
    field :description, String, null: true
    field :website, String, null: true
    field :posts_as_recruiter, Boolean, null: false,
      description: "Seen posting offers as a recruiting intermediary."
    field :posts_as_final_client, Boolean, null: false,
      description: "Seen posting offers as the final employer."
    field :aliases, [Types::CompanyAliasType], null: false,
      description: "Accepted names under which this company posts offers."
    field :offer_count, Integer, null: false,
      description: "Number of offers posted by this company."
    field :final_client_offer_count, Integer, null: false,
      description: "Number of offers where this company is the linked final client."
    field :top_technologies, [String], null: false,
      description: "Most frequent technologies across offers where this company is the final client." do
      argument :limit, Integer, required: false, default_value: 10
    end
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def offer_count
      dataloader.with(OfferCounts, :company_id).load(object.id)
    end

    def final_client_offer_count
      dataloader.with(OfferCounts, :final_company_id).load(object.id)
    end

    def top_technologies(limit:)
      object.top_technologies(limit: limit)
    end
  end
end
