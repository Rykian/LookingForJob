---
paths:
  - "db/schema.rb"
  - "db/migrate/**"
---

# Database Tables (4)

_Snapshot — may be stale after migrations. Use `rails_get_schema(table:"name")` for live data._

- **active_storage_attachments** (5 cols) — name:string, record_id:bigint, record_type:string | FK: blob_id→active_storage_blobs | Idx: record_type+record_id+name+blob_id(unique)
- **active_storage_blobs** (8 cols) — byte_size:bigint, checksum:string, content_type:string, filename:string, key:string, metadata:text, service_name:string | Idx: key(unique)
- **active_storage_variant_records** (2 cols) — variation_digest:string | FK: blob_id→active_storage_blobs | Idx: blob_id+variation_digest(unique)
- **job_offers** (27 cols) — city:string, company:string, description_html:text, employment_type:string, english_level_required:string, hybrid_remote_days_min_per_week:integer, keywords:string[](=[]), last_seen_at:datetime, location_mode:string, normalized_seniority:string, offer_language:string, posted_at:datetime, primary_technologies:string[](=[]), rejected:boolean(=false), salary_currency:string, salary_max_minor:integer, salary_min_minor:integer, score:integer, score_breakdown:jsonb, secondary_technologies:string[](=[]), source:string, steps_details:jsonb(={}), title:string, url:string, url_hash:string | Idx: url(unique), url_hash(unique)
  location_mode: remote, hybrid, on_site
  employment_type: permanent, fixed_term, contract, freelance, internship, apprenticeship, temporary, full_time, part_time
  offer_language: fr, en, other
  normalized_seniority: intern, junior, mid, senior, staff
  english_level_required: none, basic, professional, fluent