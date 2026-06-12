module Companies
  # Transactional merge/split/rename of company accepted names. An alias owns
  # all offers whose normalized_company_name matches it, so moving an alias
  # between companies relinks those offers in bulk.
  class AliasManager
    Preview = Struct.new(:normalized_name, :matched_offers_count, :owning_company, keyword_init: true)

    class OfficialNameAliasError < StandardError; end

    def preview(name)
      normalized = Company.normalize(name)
      Preview.new(
        normalized_name: normalized,
        matched_offers_count: JobOffer.where(normalized_company_name: normalized).count,
        owning_company: CompanyAlias.find_by(normalized_name: normalized)&.company
      )
    end

    # Merge: claim a name for `company`. When the alias currently belongs to
    # another company it is moved (the caller has shown the merge warning).
    # Matching offers are relinked; an emptied donor company is deleted.
    def add_alias!(company:, name:)
      normalized = Company.normalize(name)
      raise ArgumentError, "Name normalizes to blank" if normalized.blank?

      Company.transaction do
        existing = CompanyAlias.find_by(normalized_name: normalized)
        donor = existing&.company if existing && existing.company_id != company.id

        if existing.nil?
          company.aliases.create!(name: name.to_s.strip, normalized_name: normalized)
        elsif donor
          existing.update!(company: company)
        end

        relink_offers(normalized, company)
        cleanup_company(donor) if donor
      end
      company
    end

    # Split: carve a name out of its company into a fresh one, taking the
    # matching offers along. Returns the new company.
    def remove_alias!(company_alias)
      company = company_alias.company
      if company_alias.normalized_name == Company.normalize(company.name)
        raise OfficialNameAliasError, "Cannot remove the alias matching the company's official name"
      end

      new_company = nil
      Company.transaction do
        new_company = Company.create!(name: company_alias.name)
        company_alias.update!(company: new_company)
        relink_offers(company_alias.normalized_name, new_company)
      end
      Companies::EnrichmentJob.perform_later(new_company.id)
      new_company
    end

    # Rename official name. Goes through add_alias! so the new name always has
    # an alias — renaming to a name owned elsewhere is a merge.
    def rename!(company:, name:)
      stripped = name.to_s.strip
      raise ArgumentError, "Name cannot be blank" if stripped.empty?

      Company.transaction do
        add_alias!(company: company, name: stripped)
        company.update!(name: stripped)
      end
      company
    end

    private

    def relink_offers(normalized_name, company)
      JobOffer.where(normalized_company_name: normalized_name)
              .where("company_id IS DISTINCT FROM ?", company.id)
              .update_all(company_id: company.id, updated_at: Time.current)
    end

    def cleanup_company(company)
      company.reload
      return if company.aliases.exists? || company.job_offers.exists? || company.final_client_offers.exists?

      company.destroy!
    end
  end
end
