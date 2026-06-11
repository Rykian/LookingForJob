module Sourcing
  class DeduplicateOffersService
    SOURCE_PRIORITY = %w[linkedin wttj indeed apec france_travail cadremploi hellowork].freeze

    def self.normalize_text(raw)
      ActiveSupport::Inflector.transliterate(raw.to_s)
        .downcase
        .gsub(/[^a-z0-9\s]/, " ")
        .gsub(/\s+/, " ")
        .strip
    end

    def self.compute_content_fingerprint(company, title, city)
      return nil if company.blank? || title.blank?

      normalized = [
        normalize_text(company),
        normalize_text(title),
        normalize_text(city.to_s),
      ].join("|")
      Digest::SHA256.hexdigest(normalized)
    end

    def call
      backfill_fingerprints
      link_duplicates
    end

    private

    def backfill_fingerprints
      JobOffer.where(content_fingerprint: nil).where.not(company: nil).where.not(title: nil).find_each do |offer|
        fp = self.class.compute_content_fingerprint(offer.company, offer.title, offer.city)
        offer.update_column(:content_fingerprint, fp) if fp
      end
    end

    def link_duplicates
      duplicate_groups.each_slice(100) do |batch|
        batch.each do |fingerprint, offer_ids|
          assign_canonical(offer_ids)
        end
      end
    end

    def duplicate_groups
      sql = <<~SQL
        SELECT content_fingerprint, array_agg(id ORDER BY created_at ASC) AS offer_ids
        FROM job_offers
        WHERE content_fingerprint IS NOT NULL
          AND rejected = false
          AND disabled = false
          AND COALESCE(posted_at, created_at) >= NOW() - INTERVAL '14 days'
        GROUP BY content_fingerprint
        HAVING COUNT(*) > 1
      SQL
      ApplicationRecord.connection.execute(sql).map { |row| [row["content_fingerprint"], row["offer_ids"][1..-2].split(",").map(&:to_i)] }
    end

    def assign_canonical(offer_ids)
      offers = JobOffer.where(id: offer_ids).select(:id, :source, :created_at, :canonical_id).to_a
      return if offers.size < 2

      canonical = pick_canonical(offers)
      duplicate_ids = offers.map(&:id) - [canonical.id]

      # Clear canonical_id on the canonical in case it was previously a duplicate.
      canonical.update_column(:canonical_id, nil) if canonical.canonical_id.present?

      JobOffer.where(id: duplicate_ids).update_all(canonical_id: canonical.id)
    end

    def pick_canonical(offers)
      offers.min_by { |o| [o.created_at, SOURCE_PRIORITY.index(o.source) || SOURCE_PRIORITY.size] }
    end
  end
end
