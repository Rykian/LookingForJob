# frozen_string_literal: true

class BackfillContentFingerprints < ActiveRecord::Migration[8.1]
  def up
    JobOffer.where(content_fingerprint: nil).where.not(company: nil).where.not(title: nil).find_each do |offer|
      fp = Sourcing::DeduplicateService.compute_content_fingerprint(offer.company, offer.title, offer.city)
      offer.update_column(:content_fingerprint, fp) if fp
    end
    Sourcing::DeduplicateJob.perform_later
  end

  def down; end
end
