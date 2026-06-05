---
paths:
  - "db/schema.rb"
  - "db/migrate/**"
---

# Database Tables (10)

_Snapshot — may be stale after migrations. Use `rails_get_schema(table:"name")` for live data._

- **active_storage_attachments** (5 cols) — blob_id:bigint, name:string, record_id:bigint, record_type:string | FK: active_storage_blob_id→active_storage_blobs | Idx: record_type+record_id+name+blob_id(unique)
- **active_storage_blobs** (8 cols) — byte_size:bigint, checksum:string, content_type:string, filename:string, key:string, metadata:text, service_name:string | Idx: key(unique)
- **active_storage_variant_records** (2 cols) — blob_id:bigint, variation_digest:string | FK: active_storage_blob_id→active_storage_blobs | Idx: blob_id+variation_digest(unique)
- **commute_cities** (7 cols) — geocoded_at:datetime, latitude:decimal, longitude:decimal, name:string, normalized_name:string | Idx: normalized_name(unique)
- **commute_durations** (7 cols) — computed_at:datetime, destination_city_id:bigint, duration_minutes:integer, mode:string, origin_city_id:bigint | FK: commute_city_id→commute_cities, commute_city_id→commute_cities | Idx: origin_city_id+destination_city_id+mode(unique)
- **data_migrations** (0 cols)
- **job_offers** (31 cols) — canonical_id:bigint, city:string, company:string, content_fingerprint:string, description_html:text, disabled:boolean(=false), employment_type:string, english_level_required:string, hybrid_remote_days_min_per_week:integer, keywords:string[](=[]), last_seen_at:datetime, location_mode:string, normalized_seniority:string, offer_language:string, posted_at:datetime, primary_technologies:string[](=[]), rejected:boolean(=false), salary_currency:string, salary_max_minor:integer, salary_min_minor:integer, score:integer, score_breakdown:jsonb, secondary_technologies:string[](=[]), source:string, steps_details:jsonb(={}), title:string, url:string, url_hash:string | FK: commute_city_id→commute_cities, job_offer_id→job_offers | Idx: url(unique), url_hash(unique)
  location_mode: remote, hybrid, on_site
  employment_type: permanent, fixed_term, contract, freelance, internship, apprenticeship, temporary, full_time, part_time
  offer_language: fr, en, other
  normalized_seniority: intern, junior, mid, senior, staff
  english_level_required: none, basic, professional, fluent
- **pipeline_errors** (11 cols) — arguments:jsonb(={}), error_class:string, error_message:text, resolved:boolean(=false), source:string, step:string, step_version:integer | FK: job_offer_id→job_offers, run_id→runs | Idx: job_offer_id+step+resolved
- **run_job_offers** (2 cols) | FK: job_offer_id→job_offers, run_id→runs | Idx: run_id+job_offer_id(unique)
- **runs** (5 cols) — keywords:string[](=[]), providers:string[](=[]), work_modes:string[](=[])