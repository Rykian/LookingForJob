---
paths:
  - "app/models/**/*.rb"
---

# ActiveRecord Models (1)

_Quick reference — use `rails_get_model_details(model:"Name")` for live data with resolved concerns and callbacks._

- JobOffer (table: job_offers) — 2 assocs, 5 validations
  methods: employment_type_apprenticeship!, employment_type_apprenticeship?, employment_type_contract!, employment_type_contract?, employment_type_fixed_term!, employment_type_fixed_term?, employment_type_freelance!, employment_type_freelance?, employment_type_full_time!, employment_type_full_time?, employment_type_internship!, employment_type_internship?, employment_type_part_time!, employment_type_part_time?, employment_type_permanent!, employment_type_permanent?, employment_type_temporary!, employment_type_temporary?, english_level_required_basic!, english_level_required_basic?
  STEPS_DETAIL_KEYS: discovery, fetch, analyze, enrich, score
  location_mode: remote, hybrid, on_site
  employment_type: permanent, fixed_term, contract, freelance, internship, apprenticeship, temporary, full_time, part_time
  offer_language: fr, en, other
  normalized_seniority: intern, junior, mid, senior, staff
  english_level_required: none, basic, professional, fluent