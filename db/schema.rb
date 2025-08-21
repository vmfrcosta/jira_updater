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

ActiveRecord::Schema[8.0].define(version: 2025_08_21_050257) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "issues", force: :cascade do |t|
    t.string "jira_id"
    t.string "key"
    t.string "summary"
    t.string "status"
    t.string "issue_type"
    t.string "priority"
    t.string "project_key"
    t.date "start_date"
    t.date "end_date"
    t.text "labels"
    t.json "raw"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "jira_changelog_items", force: :cascade do |t|
    t.bigint "jira_changelog_id", null: false
    t.string "field"
    t.string "fieldtype"
    t.string "from_value"
    t.string "from_string"
    t.string "to_value"
    t.string "to_string"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jira_changelog_id"], name: "index_jira_changelog_items_on_jira_changelog_id"
  end

  create_table "jira_changelogs", force: :cascade do |t|
    t.bigint "jira_issue_id", null: false
    t.string "history_id"
    t.string "author_account_id"
    t.string "author_display_name"
    t.datetime "created_at_jira"
    t.jsonb "raw"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jira_issue_id"], name: "index_jira_changelogs_on_jira_issue_id"
  end

  create_table "jira_issues", force: :cascade do |t|
    t.string "jira_id"
    t.string "key"
    t.string "summary"
    t.string "status"
    t.string "issue_type"
    t.string "priority"
    t.string "project_key"
    t.date "start_date"
    t.date "end_date"
    t.json "raw"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "labels", default: [], null: false, array: true
    t.integer "points"
    t.integer "transitions_count"
    t.datetime "entered_requirements_at"
    t.datetime "entered_discovery_at"
    t.datetime "entered_ideation_at"
    t.datetime "entered_validation_at"
    t.datetime "entered_refinement_at"
    t.datetime "entered_ready_for_dev_at"
    t.datetime "entered_ready_for_review_at"
    t.datetime "entered_ready_for_test_at"
    t.datetime "entered_ready_for_deploy_at"
    t.datetime "entered_developing_at"
    t.datetime "entered_reviewing_at"
    t.datetime "entered_testing_at"
    t.datetime "entered_deployed_at"
    t.datetime "entered_wrapup_at"
    t.datetime "entered_done_at"
    t.string "reviewer"
    t.string "tester"
  end

  add_foreign_key "jira_changelog_items", "jira_changelogs"
  add_foreign_key "jira_changelogs", "jira_issues"
end
