module Sourcing
  class CompanyJob < BaseJob
    include Sourcing::Concerns::OfferJobArguments

    def perform(offer_id, options = {})
      force = extract_force(options)
      offer = find_offer(offer_id)
      return unless offer
      return if offer.rejected? || offer.disabled? || offer.reload.duplicate?

      if Sourcing::Pipeline.should_skip?(offer, "company", force:)
        Sourcing::Pipeline.advance(offer, "company", run_id, force:)
        return
      end

      result = Sourcing::CompanyStep.call(offer: offer)

      offer.update!(
        company_id: result.company_id,
        posted_by_recruiter: result.posted_by_recruiter,
        final_client_guesses: result.final_client_guesses,
        final_company_id: result.final_company_id,
        steps_details: offer.steps_details.merge("company" => {
          "at" => Time.current.iso8601,
          "version" => Sourcing::CompanyStep::VERSION,
        })
      )

      enqueue_company_enrichment([result.company_id, result.final_company_id])
      Sourcing::Pipeline.advance(offer, "company", run_id, force:)
    end

    private

    def enqueue_company_enrichment(company_ids)
      Company.where(id: company_ids.compact, enriched_at: nil).pluck(:id).each do |company_id|
        Companies::EnrichmentJob.perform_later(company_id)
      end
    end
  end
end
