---
paths:
  - "app/models/**/*.rb"
---

# ActiveRecord Models (8)

_Quick reference - use `rails_get_model_details(model:"Name")` for live data with resolved concerns and callbacks._

- Commute::City (table: commute_cities) - 3 assocs, 1 validations
  methods: inbound_durations, job_offers, outbound_durations
- Commute::Duration (table: commute_durations) - 2 assocs, 4 validations
  scopes: fresh
  methods: fresh?, cycling_mode!, cycling_mode?, destination_city, driving_mode!, driving_mode?, origin_city, walking_mode!, walking_mode?
  mode: driving, cycling, walking
- Company (table: companies) - 3 assocs, 1 validations
  methods: alias_names, top_technologies, aliases, final_client_offers, formatted, index!, job_offers, meilisearch_options, meilisearch_settings, ms_enqueue_index!, ms_enqueue_remove_from_index!, ms_entries, ms_index!, ms_remove_from_index!, ms_synchronous?, remove_from_index!
  LEGAL_SUFFIXES: sasu, sarl, sas, sa, gmbh, ltd, inc, group, groupe
- CompanyAlias (table: company_aliases) - 1 assocs, 2 validations
  methods: company
- JobOffer (table: job_offers) - 10 assocs, 5 validations
  scopes: canonical, duplicates
  methods: duplicate?, canonical?, canonical_offer, commute_city, company, duplicate_offers, employment_type_apprenticeship!, employment_type_apprenticeship?, employment_type_contract!, employment_type_contract?, employment_type_fixed_term!, employment_type_fixed_term?, employment_type_freelance!, employment_type_freelance?, employment_type_full_time!, employment_type_full_time?, employment_type_internship!, employment_type_internship?, employment_type_part_time!, employment_type_part_time?
  STEPS_DETAIL_KEYS: discovery, fetch, analyze, enrich, commute, score, company
  LANGUAGE_LEVELS: not_required, basic, professional, fluent
  location_mode: remote, hybrid, on_site
  employment_type: permanent, fixed_term, contract, freelance, internship, apprenticeship, temporary, full_time, part_time
  offer_language: fr, en, other
  normalized_seniority: intern, junior, mid, senior, staff
- PipelineError (table: pipeline_errors) - 2 assocs, 0 validations
  scopes: unresolved, for_step
  methods: job_offer, run
- Run (table: runs) - 2 assocs, 0 validations
  methods: job_offers, run_job_offers
- RunJobOffer (table: run_job_offers) - 2 assocs, 2 validations
  methods: job_offer, run