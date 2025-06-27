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

ActiveRecord::Schema[8.0].define(version: 2025_06_27_022643) do
  create_table "o_auth_sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.text "access_token"
    t.text "refresh_token"
    t.text "permissions"
    t.datetime "expires_at"
    t.string "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_o_auth_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "workos_id"
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "profile_picture_url"
    t.string "organization_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["workos_id"], name: "index_users_on_workos_id", unique: true
  end

  add_foreign_key "o_auth_sessions", "users"
end
