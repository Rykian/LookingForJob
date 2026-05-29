# frozen_string_literal: true

module Types
  module Queries
    module PipelineErrors
      extend ActiveSupport::Concern

      STEP_VALUES = ::JobOffer::STEPS_DETAIL_KEYS.dup.freeze

      included do
        field :pipeline_errors, Types::PipelineErrorsResultType, null: false,
          description: "List pipeline errors with optional filters and pagination." do
          argument :page, Integer, required: false, default_value: 1,
            description: "1-based page number."
          argument :per_page, Integer, required: false, default_value: 25,
            description: "Items per page."
          argument :resolved, GraphQL::Types::Boolean, required: false,
            description: "Filter by resolved status. Omit to return both resolved and unresolved."
          argument :steps, [String], required: false,
            description: "Filter by step (discovery, fetch, analyze, enrich, commute, score)."
          argument :sources, [String], required: false,
            description: "Filter by source (provider key)."
          argument :error_class, String, required: false,
            description: "Filter by exact error class (e.g. RuntimeError)."
          argument :run_id, GraphQL::Types::ID, required: false,
            description: "Filter by run id."
          argument :job_offer_id, GraphQL::Types::ID, required: false,
            description: "Filter by job offer id."
          argument :created_after, GraphQL::Types::ISO8601DateTime, required: false,
            description: "Filter by created_at lower bound (inclusive)."
          argument :created_before, GraphQL::Types::ISO8601DateTime, required: false,
            description: "Filter by created_at upper bound (inclusive)."
        end

        field :pipeline_error_classes, [String], null: false,
          description: "Distinct error_class values currently recorded."
        field :pipeline_error_sources, [String], null: false,
          description: "Distinct non-null source values currently recorded."
      end

      def pipeline_errors(page:, per_page:, resolved: nil, steps: nil, sources: nil, error_class: nil, run_id: nil, job_offer_id: nil, created_after: nil, created_before: nil)
        scope = ::PipelineError.all

        scope = scope.where(resolved: resolved) unless resolved.nil?
        scope = scope.where(step: steps) if steps.present?
        scope = scope.where(source: sources) if sources.present?
        scope = scope.where(error_class: error_class) if error_class.present?
        scope = scope.where(run_id: run_id) if run_id.present?
        scope = scope.where(job_offer_id: job_offer_id) if job_offer_id.present?
        scope = scope.where("created_at >= ?", created_after) if created_after.present?
        scope = scope.where("created_at <= ?", created_before) if created_before.present?

        total_count = scope.count
        total_pages = (total_count.to_f / per_page).ceil
        nodes = scope.order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)

        {
          nodes: nodes,
          total_count: total_count,
          total_pages: total_pages,
        }
      end

      def pipeline_error_classes
        ::PipelineError.distinct.order(:error_class).pluck(:error_class)
      end

      def pipeline_error_sources
        ::PipelineError.where.not(source: nil).distinct.order(:source).pluck(:source)
      end
    end
  end
end
