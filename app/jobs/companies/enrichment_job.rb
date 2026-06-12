module Companies
  # Company-scoped (not offer-scoped), so plain ApplicationJob rather than
  # Sourcing::BaseJob — there is no offer to attach a PipelineError to.
  class EnrichmentJob < ApplicationJob
    queue_as :default

    def perform(company_id, force: false)
      company = Company.find_by(id: company_id)
      return unless company
      return if !force && company.enriched_at.present? && company.enrichment_version == Companies::EnrichmentService::VERSION

      Companies::EnrichmentService.new.call(company)
    end
  end
end
