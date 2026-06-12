# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_11_132243) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "commute_cities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "geocoded_at"
    t.decimal "latitude", precision: 9, scale: 6
    t.decimal "longitude", precision: 9, scale: 6
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.datetime "updated_at", null: false
    t.index ["normalized_name"], name: "index_commute_cities_on_normalized_name", unique: true
  end

  create_table "commute_durations", force: :cascade do |t|
    t.datetime "computed_at", null: false
    t.datetime "created_at", null: false
    t.bigint "destination_city_id", null: false
    t.integer "duration_minutes", null: false
    t.string "mode", null: false
    t.bigint "origin_city_id", null: false
    t.datetime "updated_at", null: false
    t.index ["destination_city_id"], name: "index_commute_durations_on_destination_city_id"
    t.index ["origin_city_id", "destination_city_id", "mode"], name: "idx_commute_durations_triplet", unique: true
    t.index ["origin_city_id"], name: "index_commute_durations_on_origin_city_id"
  end

  create_table "companies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "enriched_at"
    t.integer "enrichment_version"
    t.string "name", null: false
    t.boolean "posts_as_final_client", default: false, null: false
    t.boolean "posts_as_recruiter", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "website"
  end

  create_table "company_aliases", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_company_aliases_on_company_id"
    t.index ["normalized_name"], name: "index_company_aliases_on_normalized_name", unique: true
  end

  create_table "data_migrations", primary_key: "version", id: :string, force: :cascade do |t|
  end

  create_table "job_offers", force: :cascade do |t|
    t.bigint "canonical_id"
    t.string "city"
    t.bigint "commute_city_id"
    t.bigint "company_id"
    t.string "company_name"
    t.string "content_fingerprint"
    t.datetime "created_at", null: false
    t.text "description_html"
    t.boolean "disabled", default: false, null: false
    t.string "employment_type"
    t.jsonb "final_client_guesses", default: [], null: false
    t.bigint "final_company_id"
    t.integer "hybrid_remote_days_min_per_week"
    t.string "keywords", default: [], null: false, array: true
    t.jsonb "languages", default: [], null: false
    t.datetime "last_seen_at", null: false
    t.string "location_mode"
    t.string "normalized_company_name"
    t.string "normalized_seniority"
    t.string "offer_language"
    t.datetime "posted_at"
    t.boolean "posted_by_recruiter"
    t.string "primary_technologies", default: [], null: false, array: true
    t.boolean "rejected", default: false, null: false
    t.string "salary_currency"
    t.integer "salary_max_minor"
    t.integer "salary_min_minor"
    t.integer "score"
    t.jsonb "score_breakdown"
    t.string "secondary_technologies", default: [], null: false, array: true
    t.string "source", null: false
    t.jsonb "steps_details", default: {}, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.string "url_hash", null: false
    t.index "(((steps_details -> 'discovery'::text) ->> 'at'::text))", name: "index_job_offers_on_discovery_at"
    t.index ["canonical_id"], name: "index_job_offers_on_canonical_id"
    t.index ["city"], name: "index_job_offers_on_city"
    t.index ["commute_city_id"], name: "index_job_offers_on_commute_city_id"
    t.index ["company_id"], name: "index_job_offers_on_company_id"
    t.index ["content_fingerprint"], name: "index_job_offers_on_content_fingerprint"
    t.index ["final_company_id"], name: "index_job_offers_on_final_company_id"
    t.index ["languages"], name: "index_job_offers_on_languages", using: :gin
    t.index ["last_seen_at"], name: "index_job_offers_on_last_seen_at"
    t.index ["location_mode"], name: "index_job_offers_on_location_mode"
    t.index ["normalized_company_name"], name: "index_job_offers_on_normalized_company_name"
    t.index ["score"], name: "index_job_offers_on_score"
    t.index ["source"], name: "index_job_offers_on_source"
    t.index ["url"], name: "index_job_offers_on_url", unique: true
    t.index ["url_hash"], name: "index_job_offers_on_url_hash", unique: true
  end

  create_table "pipeline_errors", force: :cascade do |t|
    t.jsonb "arguments", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "error_class", null: false
    t.text "error_message", null: false
    t.bigint "job_offer_id"
    t.boolean "resolved", default: false, null: false
    t.bigint "run_id"
    t.string "source"
    t.string "step", null: false
    t.integer "step_version"
    t.datetime "updated_at", null: false
    t.index ["job_offer_id", "step", "resolved"], name: "index_pipeline_errors_on_job_offer_id_and_step_and_resolved"
    t.index ["job_offer_id"], name: "index_pipeline_errors_on_job_offer_id"
    t.index ["resolved"], name: "index_pipeline_errors_on_resolved"
    t.index ["run_id"], name: "index_pipeline_errors_on_run_id"
    t.index ["step"], name: "index_pipeline_errors_on_step"
  end

  create_table "run_job_offers", force: :cascade do |t|
    t.bigint "job_offer_id", null: false
    t.bigint "run_id", null: false
    t.index ["job_offer_id"], name: "index_run_job_offers_on_job_offer_id"
    t.index ["run_id", "job_offer_id"], name: "index_run_job_offers_on_run_id_and_job_offer_id", unique: true
    t.index ["run_id"], name: "index_run_job_offers_on_run_id"
  end

  create_table "runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "keywords", default: [], null: false, array: true
    t.string "providers", default: [], null: false, array: true
    t.datetime "updated_at", null: false
    t.string "work_modes", default: [], null: false, array: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "commute_durations", "commute_cities", column: "destination_city_id"
  add_foreign_key "commute_durations", "commute_cities", column: "origin_city_id"
  add_foreign_key "company_aliases", "companies"
  add_foreign_key "job_offers", "commute_cities"
  add_foreign_key "job_offers", "companies"
  add_foreign_key "job_offers", "companies", column: "final_company_id"
  add_foreign_key "job_offers", "job_offers", column: "canonical_id", on_delete: :nullify
  add_foreign_key "pipeline_errors", "job_offers"
  add_foreign_key "pipeline_errors", "runs"
  add_foreign_key "run_job_offers", "job_offers"
  add_foreign_key "run_job_offers", "runs"
end
