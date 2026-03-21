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

ActiveRecord::Schema[8.1].define(version: 2026_03_21_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "job_offers", force: :cascade do |t|
    t.string "city"
    t.string "company"
    t.datetime "created_at", null: false
    t.text "description_html"
    t.string "employment_type"
    t.string "english_level_required"
    t.datetime "enriched_at"
    t.datetime "fetched_at"
    t.datetime "first_seen_at", null: false
    t.text "html_content"
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
    t.datetime "scored_at"
    t.jsonb "secondary_technologies"
    t.string "source", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.string "url_hash", null: false
    t.index ["city"], name: "index_job_offers_on_city"
    t.index ["scored_at"], name: "index_job_offers_on_scored_at"
    t.index ["url"], name: "index_job_offers_on_url", unique: true
    t.index ["url_hash"], name: "index_job_offers_on_url_hash", unique: true
  end
end
