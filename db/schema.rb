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

ActiveRecord::Schema[8.1].define(version: 2026_03_25_085943) do
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

  create_table "job_offers", force: :cascade do |t|
    t.string "city"
    t.string "company"
    t.datetime "created_at", null: false
    t.text "description_html"
    t.string "employment_type"
    t.string "english_level_required"
    t.integer "hybrid_remote_days_min_per_week"
    t.datetime "last_seen_at", null: false
    t.string "normalized_seniority"
    t.string "offer_language"
    t.datetime "posted_at"
    t.jsonb "primary_technologies"
    t.string "remote"
    t.string "salary_currency"
    t.integer "salary_max_minor"
    t.integer "salary_min_minor"
    t.integer "score"
    t.jsonb "score_breakdown"
    t.jsonb "secondary_technologies"
    t.string "source", null: false
    t.jsonb "steps_details", default: {}, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.string "url_hash", null: false
    t.index ["city"], name: "index_job_offers_on_city"
    t.index ["url"], name: "index_job_offers_on_url", unique: true
    t.index ["url_hash"], name: "index_job_offers_on_url_hash", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
