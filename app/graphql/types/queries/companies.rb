# frozen_string_literal: true

module Types
  module Queries
    module Companies
      extend ActiveSupport::Concern

      class CompanyAliasPreviewType < Types::BaseObject
        description "Impact preview before adding or removing a company alias."

        field :normalized_name, String, null: false
        field :matched_offers_count, Integer, null: false,
          description: "Offers whose company name matches this alias."
        field :owning_company, Types::CompanyType, null: true,
          description: "Company currently owning this alias, when it exists."
      end

      included do
        field :companies, Types::CompaniesResultType, null: false,
          description: "List companies with optional filters and pagination." do
          argument :page, Integer, required: false, default_value: 1,
            description: "1-based page number."
          argument :per_page, Integer, required: false, default_value: 25,
            description: "Items per page."
          argument :search, String, required: false,
            description: "Fuzzy search across company names and aliases."
          argument :posts_as_recruiter, GraphQL::Types::Boolean, required: false,
            description: "Filter companies seen posting as recruiters."
          argument :posts_as_final_client, GraphQL::Types::Boolean, required: false,
            description: "Filter companies seen posting as final employers."
          argument :sort_by, String, required: false, default_value: "name",
            description: "Sort field: name, created_at, offers_count."
          argument :sort_direction, String, required: false, default_value: "asc",
            description: "Sort direction: asc or desc."
        end

        field :company, Types::CompanyType, null: true,
          description: "Find a single company by ID." do
          argument :id, GraphQL::Types::ID, required: true, description: "Company ID."
        end

        field :company_alias_preview, CompanyAliasPreviewType, null: false,
          description: "Preview the impact of claiming a company name as alias (merge/split warnings)." do
          argument :name, String, required: true, description: "Raw company name."
        end

        field :company_name_suggestions, [String], null: false,
          description: "Company name candidates from offers, fuzzy-matched." do
          argument :search, String, required: true
          argument :exclude_company_id, GraphQL::Types::ID, required: false,
            description: "Exclude names already aliased to this company."
        end
      end

      def companies(page:, per_page:, search: nil, posts_as_recruiter: nil, posts_as_final_client: nil, sort_by: "name", sort_direction: "asc")
        scope = ::Company.all

        if search.present?
          raw = MeiliSearch::Rails.client.index("Company").search(search, { limit: 10_000, attributesToRetrieve: ["id"] })
          ids = raw["hits"].map { |h| h["id"].to_i }
          scope = scope.where(id: ids)
        end

        scope = scope.where(posts_as_recruiter: posts_as_recruiter) unless posts_as_recruiter.nil?
        scope = scope.where(posts_as_final_client: posts_as_final_client) unless posts_as_final_client.nil?

        sort_column = normalize_company_sort_column(sort_by)
        direction = normalize_company_sort_direction(sort_direction)

        total_count = scope.count
        total_pages = (total_count.to_f / per_page).ceil
        nodes = scope
          .order(Arel.sql("#{sort_column} #{direction} NULLS LAST, id DESC"))
          .offset((page - 1) * per_page)
          .limit(per_page)

        {
          nodes: nodes,
          total_count: total_count,
          total_pages: total_pages,
        }
      end

      def company(id:)
        ::Company.find_by(id: id)
      end

      def company_alias_preview(name:)
        ::Companies::AliasManager.new.preview(name)
      end

      def company_name_suggestions(search:, exclude_company_id: nil)
        raw = MeiliSearch::Rails.client.index("JobOffer").search(search, { limit: 1_000, attributesToRetrieve: ["id"] })
        ids = raw["hits"].map { |h| h["id"].to_i }
        names = ::JobOffer.where(id: ids).where.not(company_name: [nil, ""]).distinct.pluck(:company_name)

        if exclude_company_id.present?
          aliased = ::CompanyAlias.where(company_id: exclude_company_id).pluck(:normalized_name)
          names = names.reject { |n| aliased.include?(::Company.normalize(n)) }
        end

        names.sort.first(20)
      end

      private

      def normalize_company_sort_column(sort_by)
        allowed = {
          "name" => "name",
          "created_at" => "created_at",
          "offers_count" => "(SELECT COUNT(*) FROM job_offers WHERE job_offers.company_id = companies.id)",
        }
        allowed.fetch(sort_by.to_s, "name")
      end

      def normalize_company_sort_direction(sort_direction)
        return "desc" if sort_direction.to_s.downcase == "desc"

        "asc"
      end
    end
  end
end
