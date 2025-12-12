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

ActiveRecord::Schema[8.1].define(version: 2025_12_12_011605) do
  create_table "customers", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "hospital"
    t.integer "trucks"
    t.datetime "updated_at", null: false
  end

  create_table "monitorings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "power_status"
    t.datetime "recorded_at"
    t.decimal "temperature"
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.index ["truck_id"], name: "index_monitorings_on_truck_id"
  end

  create_table "regions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "routes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "destination"
    t.decimal "distance"
    t.integer "estimated_duration"
    t.string "name"
    t.string "origin"
    t.string "status"
    t.integer "truck_id", null: false
    t.datetime "updated_at", null: false
    t.text "waypoints"
    t.index ["truck_id"], name: "index_routes_on_truck_id"
  end

  create_table "sites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "region_id", null: false
    t.datetime "updated_at", null: false
    t.index ["region_id"], name: "index_sites_on_region_id"
  end

  create_table "trucks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "max_temp"
    t.decimal "min_temp"
    t.string "name"
    t.string "risk_level"
    t.decimal "risk_score"
    t.integer "site_id"
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["site_id"], name: "index_trucks_on_site_id"
    t.index ["user_id"], name: "index_trucks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "waypoints", force: :cascade do |t|
    t.datetime "arrival_time"
    t.datetime "created_at", null: false
    t.datetime "departure_time"
    t.integer "position"
    t.integer "route_id", null: false
    t.integer "site_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["route_id"], name: "index_waypoints_on_route_id"
    t.index ["site_id"], name: "index_waypoints_on_site_id"
  end

  add_foreign_key "monitorings", "trucks"
  add_foreign_key "routes", "trucks"
  add_foreign_key "sites", "regions"
  add_foreign_key "trucks", "sites"
  add_foreign_key "trucks", "users"
  add_foreign_key "waypoints", "routes"
  add_foreign_key "waypoints", "sites"
end
