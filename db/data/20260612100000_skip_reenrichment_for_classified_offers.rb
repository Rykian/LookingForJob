# frozen_string_literal: true

class SkipReenrichmentForClassifiedOffers < ActiveRecord::Migration[8.1]
  # The enrich VERSION bump (posted_by_recruiter field) would re-enrich every
  # active offer. Offers already classified by the old combined CompanyStep
  # carry the flag already — mark their enrich step as current so the pipeline
  # skips them. Guarded on version == current - 1 so offers stale for other
  # reasons still re-enrich.
  def up
    Sourcing::Providers.registry.sources.each do |source|
      current_version = Sourcing::Providers.registry.fetch(source).enrich_step.class::VERSION

      execute(<<~SQL.squish)
        UPDATE job_offers
        SET steps_details = jsonb_set(steps_details, '{enrich,version}', to_jsonb(#{Integer(current_version)}))
        WHERE source = #{ApplicationRecord.connection.quote(source)}
          AND posted_by_recruiter IS NOT NULL
          AND steps_details #> '{enrich,version}' IS NOT NULL
          AND (steps_details #>> '{enrich,version}')::int = #{Integer(current_version) - 1}
      SQL
    end
  end

  def down; end
end
