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

ActiveRecord::Schema[7.1].define(version: 2026_09_04_170000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_trgm"
  enable_extension "plpgsql"
  enable_extension "unaccent"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "addresses", force: :cascade do |t|
    t.string "street_name"
    t.string "street_nr"
    t.string "postal_code"
    t.string "city"
    t.string "country"
    t.string "address_type"
    t.string "addressable_type", null: false
    t.bigint "addressable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.index ["addressable_type", "addressable_id"], name: "index_addresses_on_addressable"
  end

  create_table "automation_runs", force: :cascade do |t|
    t.bigint "automation_id", null: false
    t.bigint "organisation_id", null: false
    t.string "status", default: "running", null: false
    t.boolean "manual", default: false, null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "period_start"
    t.datetime "period_end"
    t.integer "rows_count", default: 0, null: false
    t.integer "recipients_count", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "skip_reason"
    t.index ["automation_id", "created_at"], name: "index_automation_runs_on_automation_id_and_created_at"
    t.index ["automation_id"], name: "index_automation_runs_on_automation_id"
    t.index ["organisation_id"], name: "index_automation_runs_on_organisation_id"
  end

  create_table "automations", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.string "name", null: false
    t.string "kind", null: false
    t.boolean "active", default: true, null: false
    t.string "schedule_kind", default: "weekly", null: false
    t.integer "schedule_day"
    t.integer "schedule_hour", default: 9, null: false
    t.jsonb "filters", default: {}, null: false
    t.jsonb "recipients", default: {}, null: false
    t.boolean "skip_if_empty", default: true, null: false
    t.datetime "last_run_at"
    t.datetime "next_run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "schedule_minute", default: 0, null: false
    t.index ["next_run_at"], name: "index_automations_on_next_run_at"
    t.index ["organisation_id", "active"], name: "index_automations_on_organisation_id_and_active"
    t.index ["organisation_id"], name: "index_automations_on_organisation_id"
  end

  create_table "background_tasks", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.bigint "member_id", null: false
    t.string "task_type"
    t.string "status"
    t.integer "progress"
    t.integer "total"
    t.jsonb "result"
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "viewed_at"
    t.index ["member_id"], name: "index_background_tasks_on_member_id"
    t.index ["organisation_id"], name: "index_background_tasks_on_organisation_id"
    t.index ["status"], name: "index_background_tasks_on_status"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.bigint "organisation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ancestry"
    t.integer "ancestry_depth", default: 0
    t.integer "position"
    t.datetime "discarded_at"
    t.text "description"
    t.string "color"
    t.jsonb "metadata", default: {}
    t.string "slug"
    t.string "default_product_sort"
    t.boolean "published", default: true, null: false
    t.boolean "nav_bold", default: false, null: false
    t.boolean "nav_italic", default: false, null: false
    t.index ["ancestry"], name: "index_categories_on_ancestry"
    t.index ["discarded_at"], name: "index_categories_on_discarded_at"
    t.index ["organisation_id", "ancestry", "position"], name: "index_categories_on_organisation_id_and_ancestry_and_position"
    t.index ["organisation_id", "published"], name: "index_categories_on_organisation_id_and_published"
    t.index ["organisation_id", "slug"], name: "index_categories_on_organisation_id_and_slug", unique: true
    t.index ["organisation_id"], name: "index_categories_on_organisation_id"
  end

  create_table "category_products", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.bigint "product_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id", "product_id"], name: "index_category_products_on_category_id_and_product_id", unique: true
    t.index ["category_id"], name: "index_category_products_on_category_id"
    t.index ["product_id"], name: "index_category_products_on_product_id"
  end

  create_table "customer_assignments", force: :cascade do |t|
    t.bigint "org_member_id", null: false
    t.bigint "customer_id", null: false
    t.datetime "assigned_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_assignments_on_customer_id", unique: true
    t.index ["org_member_id"], name: "index_customer_assignments_on_org_member_id"
  end

  create_table "customer_categories", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organisation_id", "name"], name: "index_customer_categories_on_organisation_id_and_name", unique: true
    t.index ["organisation_id"], name: "index_customer_categories_on_organisation_id"
  end

  create_table "customer_discounts", force: :cascade do |t|
    t.bigint "customer_id"
    t.bigint "organisation_id", null: false
    t.string "discount_type", default: "percentage", null: false
    t.decimal "discount_value", precision: 10, scale: 4, null: false
    t.date "valid_from"
    t.date "valid_until"
    t.boolean "stackable", default: false, null: false
    t.boolean "active", default: true, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "customer_category_id"
    t.index ["customer_category_id"], name: "index_customer_discounts_on_customer_category_id"
    t.index ["customer_id", "organisation_id"], name: "index_customer_discounts_on_customer_id_and_organisation_id"
    t.index ["customer_id"], name: "index_customer_discounts_on_customer_id"
    t.index ["organisation_id"], name: "index_customer_discounts_on_organisation_id"
  end

  create_table "customer_product_discounts", force: :cascade do |t|
    t.bigint "customer_id"
    t.bigint "product_id"
    t.bigint "organisation_id", null: false
    t.decimal "discount_value", precision: 10, scale: 4, default: "0.0"
    t.date "valid_from"
    t.date "valid_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "discount_type", default: "percentage", null: false
    t.boolean "stackable", default: false, null: false
    t.boolean "active", default: true, null: false
    t.bigint "category_id"
    t.bigint "customer_category_id"
    t.string "condition_type", default: "none", null: false
    t.integer "min_quantity"
    t.integer "min_amount_cents"
    t.string "condition_scope", default: "per_line", null: false
    t.index ["category_id"], name: "index_customer_product_discounts_on_category_id"
    t.index ["customer_category_id"], name: "index_customer_product_discounts_on_customer_category_id"
    t.index ["customer_id"], name: "index_customer_product_discounts_on_customer_id"
    t.index ["organisation_id"], name: "index_customer_product_discounts_on_organisation_id"
    t.index ["product_id"], name: "index_customer_product_discounts_on_product_id"
  end

  create_table "customer_user_login_events", force: :cascade do |t|
    t.bigint "customer_user_id"
    t.bigint "organisation_id", null: false
    t.string "method", null: false
    t.boolean "success", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.string "failure_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_user_id", "created_at"], name: "idx_on_customer_user_id_created_at_d938badb1a"
    t.index ["customer_user_id"], name: "index_customer_user_login_events_on_customer_user_id"
    t.index ["organisation_id", "created_at"], name: "idx_on_organisation_id_created_at_def3a1a86e"
    t.index ["organisation_id"], name: "index_customer_user_login_events_on_organisation_id"
  end

  create_table "customer_users", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "organisation_id", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.string "invited_by_type"
    t.bigint "invited_by_id"
    t.integer "invitations_count", default: 0
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "contact_name"
    t.string "contact_phone"
    t.string "locale"
    t.boolean "email_notifications_enabled", default: true, null: false
    t.boolean "hide_prices", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_seen_at"
    t.index ["customer_id"], name: "index_customer_users_on_customer_id"
    t.index ["email", "organisation_id"], name: "index_customer_users_on_email_and_organisation_id", unique: true, where: "((email)::text <> ''::text)"
    t.index ["invitation_token"], name: "index_customer_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_customer_users_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_customer_users_on_invited_by_type_and_invited_by_id"
    t.index ["last_seen_at"], name: "index_customer_users_on_last_seen_at"
    t.index ["locale"], name: "index_customer_users_on_locale"
    t.index ["organisation_id"], name: "index_customer_users_on_organisation_id"
    t.index ["reset_password_token"], name: "index_customer_users_on_reset_password_token", unique: true
  end

  create_table "customers", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.bigint "organisation_id", null: false
    t.string "company_name"
    t.string "contact_name"
    t.string "contact_phone"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.string "invited_by_type"
    t.bigint "invited_by_id"
    t.integer "invitations_count", default: 0
    t.string "locale"
    t.string "external_id"
    t.string "external_source"
    t.datetime "last_synced_at"
    t.text "sync_error"
    t.string "taxpayer_id"
    t.boolean "email_notifications_enabled", default: true, null: false
    t.bigint "customer_category_id"
    t.integer "sign_in_count"
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.boolean "hide_prices", default: false, null: false
    t.bigint "created_by_member_id"
    t.index ["created_by_member_id"], name: "index_customers_on_created_by_member_id"
    t.index ["customer_category_id"], name: "index_customers_on_customer_category_id"
    t.index ["email", "organisation_id"], name: "index_customers_on_email_and_organisation_id", unique: true, where: "((email)::text <> ''::text)"
    t.index ["invitation_token"], name: "index_customers_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_customers_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_customers_on_invited_by"
    t.index ["locale"], name: "index_customers_on_locale"
    t.index ["organisation_id", "external_id", "external_source"], name: "index_customers_on_org_external_id_source", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["organisation_id", "taxpayer_id"], name: "index_customers_on_org_id_taxpayer_id_unique", unique: true, where: "((taxpayer_id IS NOT NULL) AND ((taxpayer_id)::text <> ''::text))"
    t.index ["organisation_id"], name: "index_customers_on_organisation_id"
    t.index ["reset_password_token"], name: "index_customers_on_reset_password_token", unique: true
  end

  create_table "discount_email_notifications", force: :cascade do |t|
    t.string "notifiable_type", null: false
    t.bigint "notifiable_id", null: false
    t.bigint "organisation_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "recipient_count", default: 0
    t.datetime "sent_at"
    t.bigint "sent_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "idx_den_on_notifiable", unique: true
    t.index ["notifiable_type", "notifiable_id"], name: "index_discount_email_notifications_on_notifiable"
    t.index ["organisation_id", "status"], name: "idx_on_organisation_id_status_7657d575d3"
    t.index ["organisation_id"], name: "index_discount_email_notifications_on_organisation_id"
    t.index ["sent_by_id"], name: "index_discount_email_notifications_on_sent_by_id"
  end

  create_table "email_logs", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.bigint "customer_id"
    t.bigint "member_id"
    t.string "email_type", null: false
    t.string "mailer_class", null: false
    t.string "recipient_email", null: false
    t.string "subject"
    t.string "status", default: "sent", null: false
    t.string "error_message"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_email_logs_on_customer_id"
    t.index ["member_id"], name: "index_email_logs_on_member_id"
    t.index ["organisation_id", "sent_at"], name: "index_email_logs_on_organisation_id_and_sent_at"
    t.index ["organisation_id"], name: "index_email_logs_on_organisation_id"
    t.index ["status"], name: "index_email_logs_on_status"
  end

  create_table "erp_configurations", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.boolean "enabled", default: false
    t.string "adapter_type"
    t.text "credentials_ciphertext"
    t.boolean "sync_products", default: true
    t.boolean "sync_customers", default: true
    t.boolean "sync_orders", default: false
    t.string "sync_frequency", default: "daily"
    t.datetime "last_sync_at"
    t.string "last_sync_status"
    t.text "last_sync_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "product_sync_mode"
    t.index ["organisation_id"], name: "index_erp_configurations_on_organisation_id", unique: true
  end

  create_table "erp_sync_logs", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.bigint "erp_configuration_id", null: false
    t.string "sync_type"
    t.string "entity_type"
    t.string "status"
    t.integer "records_processed", default: 0
    t.integer "records_created", default: 0
    t.integer "records_updated", default: 0
    t.integer "records_failed", default: 0
    t.datetime "started_at"
    t.datetime "completed_at"
    t.jsonb "error_details", default: []
    t.text "summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "change_details"
    t.index ["erp_configuration_id"], name: "index_erp_sync_logs_on_erp_configuration_id"
    t.index ["organisation_id", "created_at"], name: "index_erp_sync_logs_on_organisation_id_and_created_at"
    t.index ["organisation_id"], name: "index_erp_sync_logs_on_organisation_id"
  end

  create_table "homepage_banners", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.string "title"
    t.string "subtitle"
    t.string "link_url"
    t.string "link_text"
    t.integer "position"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "text_theme"
    t.index ["organisation_id"], name: "index_homepage_banners_on_organisation_id"
  end

  create_table "homepage_featured_categories", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.bigint "category_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_homepage_featured_categories_on_category_id"
    t.index ["organisation_id"], name: "index_homepage_featured_categories_on_organisation_id"
  end

  create_table "homepage_featured_products", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.bigint "product_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organisation_id"], name: "index_homepage_featured_products_on_organisation_id"
    t.index ["product_id"], name: "index_homepage_featured_products_on_product_id"
  end

  create_table "homepage_special_price_products", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.bigint "product_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organisation_id", "product_id"], name: "index_special_price_products_on_org_and_product", unique: true
    t.index ["organisation_id"], name: "index_homepage_special_price_products_on_organisation_id"
    t.index ["product_id"], name: "index_homepage_special_price_products_on_product_id"
  end

  create_table "members", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "locale"
    t.index ["email"], name: "index_members_on_email", unique: true
    t.index ["locale"], name: "index_members_on_locale"
    t.index ["reset_password_token"], name: "index_members_on_reset_password_token", unique: true
  end

  create_table "order_discounts", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.string "discount_type", null: false
    t.decimal "discount_value", precision: 10, scale: 4, null: false
    t.integer "min_order_amount_cents", null: false
    t.date "valid_from"
    t.date "valid_until"
    t.boolean "stackable", default: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organisation_id", "active"], name: "index_order_discounts_on_organisation_id_and_active"
    t.index ["organisation_id"], name: "index_order_discounts_on_organisation_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.integer "unit_price", null: false
    t.decimal "discount_percentage", precision: 5, scale: 4, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_variant_id"
    t.text "note"
    t.index ["order_id", "product_id", "product_variant_id"], name: "idx_order_items_order_product_variant", unique: true
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.index ["product_variant_id"], name: "index_order_items_on_product_variant_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "organisation_id", null: false
    t.string "order_number", null: false
    t.string "status", default: "in_process"
    t.string "payment_status", default: "pending"
    t.datetime "placed_at"
    t.date "receive_on"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "tax_amount_cents"
    t.string "tax_amount_currency"
    t.integer "shipping_amount_cents"
    t.string "shipping_amount_currency"
    t.string "delivery_method", default: "delivery"
    t.bigint "shipping_address_id"
    t.bigint "billing_address_id"
    t.string "discount_type"
    t.decimal "discount_value", precision: 10, scale: 4
    t.text "discount_reason"
    t.bigint "applied_by_id"
    t.bigint "order_discount_id"
    t.string "auto_discount_type"
    t.decimal "auto_discount_value", precision: 10, scale: 4
    t.integer "auto_discount_amount_cents"
    t.string "external_id"
    t.string "external_source"
    t.datetime "last_synced_at"
    t.text "sync_error"
    t.datetime "viewed_at"
    t.datetime "terms_accepted_at"
    t.bigint "promo_code_id"
    t.integer "promo_code_discount_amount_cents", default: 0
    t.string "push_status", default: "pending", null: false
    t.integer "push_attempts", default: 0, null: false
    t.datetime "last_pushed_at"
    t.bigint "customer_user_id", null: false
    t.string "placed_by_type"
    t.bigint "placed_by_id"
    t.bigint "sales_rep_id"
    t.datetime "pricing_changed_at"
    t.boolean "shipping_pending", default: false, null: false
    t.index ["applied_by_id"], name: "index_orders_on_applied_by_id"
    t.index ["billing_address_id"], name: "index_orders_on_billing_address_id"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["customer_user_id"], name: "index_orders_on_customer_user_id"
    t.index ["order_discount_id"], name: "index_orders_on_order_discount_id"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["organisation_id", "customer_id"], name: "index_orders_on_organisation_id_and_customer_id"
    t.index ["organisation_id", "external_id", "external_source"], name: "index_orders_on_org_external_id_source", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["organisation_id", "placed_at"], name: "index_orders_on_organisation_id_and_placed_at"
    t.index ["organisation_id", "push_status"], name: "index_orders_on_organisation_id_and_push_status"
    t.index ["organisation_id"], name: "index_orders_on_organisation_id"
    t.index ["placed_by_type", "placed_by_id"], name: "index_orders_on_placed_by"
    t.index ["promo_code_id"], name: "index_orders_on_promo_code_id"
    t.index ["sales_rep_id"], name: "index_orders_on_sales_rep_id"
    t.index ["shipping_address_id"], name: "index_orders_on_shipping_address_id"
  end

  create_table "org_members", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.bigint "member_id"
    t.string "role"
    t.datetime "joined_at"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "invitation_token"
    t.datetime "invitation_sent_at"
    t.bigint "invited_by_id"
    t.datetime "invitation_accepted_at"
    t.string "invited_email"
    t.boolean "receive_order_notifications"
    t.boolean "is_sales_rep", default: false, null: false
    t.index ["invitation_token"], name: "index_org_members_on_invitation_token", unique: true
    t.index ["member_id"], name: "index_org_members_on_member_id"
    t.index ["organisation_id", "is_sales_rep"], name: "index_org_members_on_org_id_sales_reps", where: "(is_sales_rep = true)"
    t.index ["organisation_id"], name: "index_org_members_on_organisation_id"
  end

  create_table "organisations", force: :cascade do |t|
    t.string "name"
    t.string "slug", null: false
    t.string "billing_email"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "tax_rate", precision: 5, scale: 4, default: "0.08"
    t.integer "shipping_cost_cents", default: 1500
    t.string "shipping_cost_currency", default: "EUR"
    t.string "currency", default: "EUR", null: false
    t.string "default_locale", default: "en", null: false
    t.string "primary_color", default: "#008060"
    t.string "secondary_color", default: "#004c3f"
    t.string "contact_email"
    t.string "phone"
    t.string "whatsapp"
    t.text "business_hours"
    t.boolean "use_billing_address_for_contact"
    t.string "storefront_title"
    t.string "taxpayer_id"
    t.integer "free_shipping_threshold_cents"
    t.string "free_shipping_threshold_currency", default: "EUR"
    t.boolean "show_related_products", default: true, null: false
    t.string "out_of_stock_strategy", default: "do_nothing", null: false
    t.boolean "show_product_sku"
    t.boolean "show_product_min_quantity"
    t.boolean "show_product_category"
    t.boolean "show_product_availability"
    t.string "instagram_url"
    t.string "facebook_url"
    t.string "linkedin_url"
    t.boolean "show_whatsapp_button"
    t.boolean "show_scroll_to_top"
    t.string "email_sender_name"
    t.string "email_reply_to"
    t.boolean "email_order_confirmation_enabled", default: true, null: false
    t.boolean "email_discount_notification_enabled", default: true, null: false
    t.boolean "email_customer_invitation_enabled", default: true, null: false
    t.boolean "email_member_order_notification_enabled", default: true, null: false
    t.integer "delivery_days", default: 62, null: false
    t.string "order_cutoff_time"
    t.integer "lead_time_days", default: 1, null: false
    t.string "timezone", default: "Europe/Lisbon", null: false
    t.string "hero_title"
    t.string "hero_subtitle"
    t.string "hero_link_url"
    t.string "hero_link_text"
    t.string "default_product_sort", default: "name_asc", null: false
    t.boolean "special_prices_show_price", default: true, null: false
    t.boolean "special_prices_show_discount_badge", default: true, null: false
    t.boolean "special_prices_show_sale_badge", default: true, null: false
    t.integer "quick_access_token_ttl_days", default: 90
    t.string "custom_domain"
    t.datetime "custom_domain_verified_at"
    t.string "cart_stock_policy", default: "warn", null: false
    t.string "cart_qty_overflow_policy", default: "warn", null: false
    t.string "checkout_stock_policy", default: "warn", null: false
    t.string "cart_price_change_policy", default: "notify", null: false
    t.text "storefront_description"
    t.string "website_url"
    t.decimal "max_discount_percentage", precision: 5, scale: 4
    t.string "campaign_color"
    t.integer "low_stock_threshold", default: 5, null: false
    t.string "sale_badge_text"
    t.string "sale_badge_color"
    t.boolean "show_sale_badge", default: true, null: false
    t.boolean "show_product_sku_on_card", default: false, null: false
    t.string "shipping_mode", default: "fixed", null: false
    t.boolean "email_automation_enabled", default: true, null: false
    t.index ["custom_domain"], name: "index_organisations_on_custom_domain", unique: true, where: "(custom_domain IS NOT NULL)"
    t.index ["default_locale"], name: "index_organisations_on_default_locale"
    t.index ["slug"], name: "index_organisations_on_slug", unique: true
  end

  create_table "product_attribute_values", force: :cascade do |t|
    t.bigint "product_attribute_id", null: false
    t.string "value", null: false
    t.string "slug", null: false
    t.string "color_hex"
    t.integer "position"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_attribute_id", "position"], name: "idx_attr_values_on_attr_id_and_position"
    t.index ["product_attribute_id", "slug"], name: "idx_attr_values_on_attr_id_and_slug", unique: true
    t.index ["product_attribute_id"], name: "index_product_attribute_values_on_product_attribute_id"
  end

  create_table "product_attributes", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.integer "position"
    t.boolean "active", default: true, null: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "display_type"
    t.boolean "show_on_card"
    t.string "card_display_mode"
    t.index ["discarded_at"], name: "index_product_attributes_on_discarded_at"
    t.index ["organisation_id", "position"], name: "index_product_attributes_on_organisation_id_and_position"
    t.index ["organisation_id", "slug"], name: "index_product_attributes_on_organisation_id_and_slug", unique: true
    t.index ["organisation_id"], name: "index_product_attributes_on_organisation_id"
  end

  create_table "product_available_values", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "product_attribute_value_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_attribute_value_id"], name: "index_product_available_values_on_product_attribute_value_id"
    t.index ["product_id", "product_attribute_value_id"], name: "idx_product_available_values_unique", unique: true
    t.index ["product_id"], name: "index_product_available_values_on_product_id"
  end

  create_table "product_discounts", force: :cascade do |t|
    t.bigint "product_id"
    t.bigint "organisation_id", null: false
    t.string "discount_type", default: "percentage", null: false
    t.decimal "discount_value", precision: 10, scale: 4, null: false
    t.integer "min_quantity", default: 1, null: false
    t.date "valid_from"
    t.date "valid_until"
    t.boolean "stackable", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "category_id"
    t.string "condition_type", default: "quantity", null: false
    t.integer "min_amount_cents"
    t.string "condition_scope", default: "per_line", null: false
    t.index ["category_id"], name: "index_product_discounts_on_category_id"
    t.index ["organisation_id"], name: "index_product_discounts_on_organisation_id"
    t.index ["product_id", "organisation_id"], name: "index_product_discounts_on_product_id_and_organisation_id"
    t.index ["product_id"], name: "index_product_discounts_on_product_id"
  end

  create_table "product_product_attributes", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "product_attribute_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_attribute_id"], name: "index_product_product_attributes_on_product_attribute_id"
    t.index ["product_id", "product_attribute_id"], name: "idx_product_product_attributes_unique", unique: true
    t.index ["product_id"], name: "index_product_product_attributes_on_product_id"
  end

  create_table "product_variants", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.bigint "product_id", null: false
    t.string "sku"
    t.string "name"
    t.integer "unit_price_cents"
    t.string "unit_price_currency", default: "EUR"
    t.integer "stock_quantity", default: 0
    t.boolean "track_stock", default: true, null: false
    t.boolean "available", default: true, null: false
    t.boolean "is_default", default: false, null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id"
    t.string "external_source"
    t.datetime "last_synced_at"
    t.text "sync_error"
    t.boolean "exclude_from_discounts"
    t.string "custom_discount_type"
    t.decimal "custom_discount_value"
    t.boolean "published", default: true, null: false
    t.string "stock_policy", default: "inherit", null: false
    t.index ["organisation_id", "sku"], name: "index_product_variants_on_organisation_id_and_sku", unique: true, where: "((sku IS NOT NULL) AND ((sku)::text <> ''::text))"
    t.index ["organisation_id"], name: "index_product_variants_on_organisation_id"
    t.index ["product_id", "available"], name: "index_product_variants_on_product_id_and_available"
    t.index ["product_id", "external_id", "external_source"], name: "index_product_variants_on_product_external_id_source", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["product_id", "is_default"], name: "index_product_variants_on_product_id_and_is_default"
    t.index ["product_id", "position"], name: "index_product_variants_on_product_id_and_position"
    t.index ["product_id"], name: "index_product_variants_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.string "name"
    t.string "slug", null: false
    t.string "sku"
    t.text "description"
    t.integer "unit_price"
    t.string "unit_description"
    t.integer "min_quantity"
    t.string "min_quantity_type"
    t.boolean "available", default: true, null: false
    t.bigint "category_id"
    t.json "product_attributes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "has_variants", default: false, null: false
    t.boolean "variants_generated", default: false, null: false
    t.string "external_id"
    t.string "external_source"
    t.datetime "last_synced_at"
    t.text "sync_error"
    t.boolean "hide_related_products", default: false, null: false
    t.bigint "cover_photo_blob_id"
    t.boolean "price_on_request"
    t.boolean "featured"
    t.boolean "published", default: true, null: false
    t.string "add_to_cart_mode", default: "default", null: false
    t.string "min_quantity_scope", default: "per_variant", null: false
    t.string "supplier"
    t.boolean "hide_sku_on_card", default: false, null: false
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["organisation_id", "external_id", "external_source"], name: "index_products_on_org_external_id_source", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["organisation_id"], name: "index_products_on_organisation_id"
    t.index ["slug"], name: "index_products_on_slug", unique: true
  end

  create_table "promo_code_customer_categories", force: :cascade do |t|
    t.bigint "promo_code_id", null: false
    t.bigint "customer_category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_category_id"], name: "index_promo_code_customer_categories_on_customer_category_id"
    t.index ["promo_code_id", "customer_category_id"], name: "idx_promo_code_customer_categories_unique", unique: true
    t.index ["promo_code_id"], name: "index_promo_code_customer_categories_on_promo_code_id"
  end

  create_table "promo_code_customers", force: :cascade do |t|
    t.bigint "promo_code_id", null: false
    t.bigint "customer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_promo_code_customers_on_customer_id"
    t.index ["promo_code_id", "customer_id"], name: "index_promo_code_customers_on_promo_code_id_and_customer_id", unique: true
    t.index ["promo_code_id"], name: "index_promo_code_customers_on_promo_code_id"
  end

  create_table "promo_code_redemptions", force: :cascade do |t|
    t.bigint "promo_code_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "order_id", null: false
    t.integer "discount_amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_promo_code_redemptions_on_customer_id"
    t.index ["order_id"], name: "index_promo_code_redemptions_on_order_id", unique: true
    t.index ["promo_code_id"], name: "index_promo_code_redemptions_on_promo_code_id"
  end

  create_table "promo_codes", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.string "code", null: false
    t.text "description"
    t.string "discount_type", null: false
    t.decimal "discount_value", precision: 10, scale: 4, null: false
    t.integer "min_order_amount_cents", default: 0
    t.integer "usage_limit"
    t.integer "usage_count", default: 0, null: false
    t.integer "per_customer_limit", default: 1, null: false
    t.string "eligibility", default: "all_customers", null: false
    t.date "valid_from"
    t.date "valid_until"
    t.boolean "stackable", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organisation_id", "code"], name: "index_promo_codes_on_organisation_id_and_code", unique: true
    t.index ["organisation_id"], name: "index_promo_codes_on_organisation_id"
  end

  create_table "quick_access_tokens", force: :cascade do |t|
    t.bigint "customer_user_id", null: false
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.bigint "created_by_member_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_member_id"], name: "index_quick_access_tokens_on_created_by_member_id"
    t.index ["customer_user_id", "revoked_at"], name: "index_quick_access_tokens_on_customer_user_id_and_revoked_at"
    t.index ["customer_user_id"], name: "index_quick_access_tokens_on_customer_user_id"
    t.index ["token"], name: "index_quick_access_tokens_on_token", unique: true
  end

  create_table "related_products", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "related_product_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_related_products_on_product_id"
    t.index ["related_product_id"], name: "index_related_products_on_related_product_id"
  end

  create_table "shopping_list_items", force: :cascade do |t|
    t.bigint "shopping_list_id", null: false
    t.bigint "product_id", null: false
    t.bigint "product_variant_id"
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_shopping_list_items_on_product_id"
    t.index ["product_variant_id"], name: "index_shopping_list_items_on_product_variant_id"
    t.index ["shopping_list_id", "product_id", "product_variant_id"], name: "idx_shopping_list_items_uniqueness", unique: true
    t.index ["shopping_list_id"], name: "index_shopping_list_items_on_shopping_list_id"
  end

  create_table "shopping_lists", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "organisation_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "notes"
    t.index ["customer_id", "organisation_id"], name: "index_shopping_lists_on_customer_id_and_organisation_id"
    t.index ["customer_id"], name: "index_shopping_lists_on_customer_id"
    t.index ["organisation_id"], name: "index_shopping_lists_on_organisation_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "stock_events", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.bigint "product_variant_id", null: false
    t.string "kind", null: false
    t.integer "from_quantity"
    t.integer "to_quantity"
    t.datetime "occurred_at", null: false
    t.string "source", default: "app", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organisation_id", "kind", "occurred_at"], name: "index_stock_events_on_organisation_id_and_kind_and_occurred_at"
    t.index ["organisation_id"], name: "index_stock_events_on_organisation_id"
    t.index ["product_variant_id", "occurred_at"], name: "index_stock_events_on_product_variant_id_and_occurred_at"
    t.index ["product_variant_id"], name: "index_stock_events_on_product_variant_id"
  end

  create_table "unmet_demand_occurrences", force: :cascade do |t|
    t.bigint "unmet_demand_id"
    t.bigint "organisation_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "customer_user_id", null: false
    t.bigint "product_id", null: false
    t.bigint "product_variant_id"
    t.integer "requested_quantity", null: false
    t.integer "kept_quantity", default: 0, null: false
    t.string "reason", null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_unmet_demand_occurrences_on_customer_id"
    t.index ["customer_user_id", "product_id", "product_variant_id"], name: "index_unmet_demand_occurrences_on_login_product_variant"
    t.index ["customer_user_id"], name: "index_unmet_demand_occurrences_on_customer_user_id"
    t.index ["organisation_id"], name: "index_unmet_demand_occurrences_on_organisation_id"
    t.index ["product_id"], name: "index_unmet_demand_occurrences_on_product_id"
    t.index ["product_variant_id"], name: "index_unmet_demand_occurrences_on_product_variant_id"
    t.index ["unmet_demand_id"], name: "index_unmet_demand_occurrences_on_unmet_demand_id"
  end

  create_table "unmet_demands", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "customer_user_id", null: false
    t.bigint "product_id", null: false
    t.bigint "product_variant_id"
    t.bigint "order_id"
    t.bigint "substitute_product_id"
    t.bigint "resolved_by_member_id"
    t.integer "requested_quantity", null: false
    t.integer "fulfilled_quantity", default: 0, null: false
    t.string "reason", null: false
    t.string "status", default: "open", null: false
    t.string "resolution"
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "customer_user_id, product_id, COALESCE(product_variant_id, (0)::bigint)", name: "index_unmet_demands_open_uniqueness", unique: true, where: "((status)::text = 'open'::text)"
    t.index ["customer_id", "status"], name: "index_unmet_demands_on_customer_id_and_status"
    t.index ["customer_id"], name: "index_unmet_demands_on_customer_id"
    t.index ["customer_user_id"], name: "index_unmet_demands_on_customer_user_id"
    t.index ["order_id"], name: "index_unmet_demands_on_order_id"
    t.index ["organisation_id", "status"], name: "index_unmet_demands_on_organisation_id_and_status"
    t.index ["organisation_id"], name: "index_unmet_demands_on_organisation_id"
    t.index ["product_id"], name: "index_unmet_demands_on_product_id"
    t.index ["product_variant_id"], name: "index_unmet_demands_on_product_variant_id"
    t.index ["substitute_product_id"], name: "index_unmet_demands_on_substitute_product_id"
  end

  create_table "variant_attribute_values", force: :cascade do |t|
    t.bigint "product_variant_id", null: false
    t.bigint "product_attribute_value_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_attribute_value_id"], name: "index_variant_attribute_values_on_product_attribute_value_id"
    t.index ["product_variant_id", "product_attribute_value_id"], name: "idx_variant_attribute_values_unique", unique: true
    t.index ["product_variant_id"], name: "index_variant_attribute_values_on_product_variant_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "automation_runs", "automations"
  add_foreign_key "automation_runs", "organisations"
  add_foreign_key "automations", "organisations"
  add_foreign_key "background_tasks", "members"
  add_foreign_key "background_tasks", "organisations"
  add_foreign_key "categories", "organisations"
  add_foreign_key "category_products", "categories"
  add_foreign_key "category_products", "products"
  add_foreign_key "customer_assignments", "customers"
  add_foreign_key "customer_assignments", "org_members"
  add_foreign_key "customer_categories", "organisations"
  add_foreign_key "customer_discounts", "customer_categories"
  add_foreign_key "customer_discounts", "customers"
  add_foreign_key "customer_discounts", "organisations"
  add_foreign_key "customer_product_discounts", "categories"
  add_foreign_key "customer_product_discounts", "customer_categories"
  add_foreign_key "customer_product_discounts", "customers"
  add_foreign_key "customer_product_discounts", "organisations"
  add_foreign_key "customer_product_discounts", "products"
  add_foreign_key "customer_user_login_events", "customer_users"
  add_foreign_key "customer_user_login_events", "organisations"
  add_foreign_key "customer_users", "customers"
  add_foreign_key "customer_users", "organisations"
  add_foreign_key "customers", "customer_categories"
  add_foreign_key "customers", "org_members", column: "created_by_member_id"
  add_foreign_key "customers", "organisations"
  add_foreign_key "discount_email_notifications", "members", column: "sent_by_id"
  add_foreign_key "discount_email_notifications", "organisations"
  add_foreign_key "email_logs", "customers"
  add_foreign_key "email_logs", "members"
  add_foreign_key "email_logs", "organisations"
  add_foreign_key "erp_configurations", "organisations"
  add_foreign_key "erp_sync_logs", "erp_configurations"
  add_foreign_key "erp_sync_logs", "organisations"
  add_foreign_key "homepage_banners", "organisations"
  add_foreign_key "homepage_featured_categories", "categories"
  add_foreign_key "homepage_featured_categories", "organisations"
  add_foreign_key "homepage_featured_products", "organisations"
  add_foreign_key "homepage_featured_products", "products"
  add_foreign_key "homepage_special_price_products", "organisations"
  add_foreign_key "homepage_special_price_products", "products"
  add_foreign_key "order_discounts", "organisations"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "product_variants"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "addresses", column: "billing_address_id"
  add_foreign_key "orders", "addresses", column: "shipping_address_id"
  add_foreign_key "orders", "customer_users"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "members", column: "applied_by_id"
  add_foreign_key "orders", "order_discounts"
  add_foreign_key "orders", "org_members", column: "sales_rep_id"
  add_foreign_key "orders", "organisations"
  add_foreign_key "orders", "promo_codes"
  add_foreign_key "org_members", "members"
  add_foreign_key "org_members", "organisations"
  add_foreign_key "product_attribute_values", "product_attributes"
  add_foreign_key "product_attributes", "organisations"
  add_foreign_key "product_available_values", "product_attribute_values"
  add_foreign_key "product_available_values", "products"
  add_foreign_key "product_discounts", "categories"
  add_foreign_key "product_discounts", "organisations"
  add_foreign_key "product_discounts", "products"
  add_foreign_key "product_product_attributes", "product_attributes"
  add_foreign_key "product_product_attributes", "products"
  add_foreign_key "product_variants", "organisations"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "categories"
  add_foreign_key "products", "organisations"
  add_foreign_key "promo_code_customer_categories", "customer_categories"
  add_foreign_key "promo_code_customer_categories", "promo_codes"
  add_foreign_key "promo_code_customers", "customers"
  add_foreign_key "promo_code_customers", "promo_codes"
  add_foreign_key "promo_code_redemptions", "customers"
  add_foreign_key "promo_code_redemptions", "orders"
  add_foreign_key "promo_code_redemptions", "promo_codes"
  add_foreign_key "promo_codes", "organisations"
  add_foreign_key "quick_access_tokens", "customer_users"
  add_foreign_key "quick_access_tokens", "members", column: "created_by_member_id"
  add_foreign_key "related_products", "products"
  add_foreign_key "related_products", "products", column: "related_product_id", name: "fk_rails_related_product_id"
  add_foreign_key "shopping_list_items", "product_variants"
  add_foreign_key "shopping_list_items", "products"
  add_foreign_key "shopping_list_items", "shopping_lists"
  add_foreign_key "shopping_lists", "customers"
  add_foreign_key "shopping_lists", "organisations"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "stock_events", "organisations"
  add_foreign_key "stock_events", "product_variants"
  add_foreign_key "unmet_demand_occurrences", "customer_users"
  add_foreign_key "unmet_demand_occurrences", "customers"
  add_foreign_key "unmet_demand_occurrences", "organisations"
  add_foreign_key "unmet_demand_occurrences", "product_variants"
  add_foreign_key "unmet_demand_occurrences", "products"
  add_foreign_key "unmet_demand_occurrences", "unmet_demands", on_delete: :nullify
  add_foreign_key "unmet_demands", "customer_users"
  add_foreign_key "unmet_demands", "customers"
  add_foreign_key "unmet_demands", "orders", on_delete: :nullify
  add_foreign_key "unmet_demands", "organisations"
  add_foreign_key "unmet_demands", "product_variants"
  add_foreign_key "unmet_demands", "products"
  add_foreign_key "unmet_demands", "products", column: "substitute_product_id", on_delete: :nullify
  add_foreign_key "variant_attribute_values", "product_attribute_values"
  add_foreign_key "variant_attribute_values", "product_variants"
end
