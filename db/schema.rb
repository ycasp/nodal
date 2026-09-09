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

ActiveRecord::Schema[7.1].define(version: 2026_01_29_174050) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
    t.index ["ancestry"], name: "index_categories_on_ancestry"
    t.index ["discarded_at"], name: "index_categories_on_discarded_at"
    t.index ["organisation_id", "ancestry", "position"], name: "index_categories_on_organisation_id_and_ancestry_and_position"
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

  create_table "customer_discounts", force: :cascade do |t|
    t.bigint "customer_id", null: false
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
    t.index ["customer_id", "organisation_id"], name: "index_customer_discounts_on_customer_id_and_organisation_id"
    t.index ["customer_id"], name: "index_customer_discounts_on_customer_id"
    t.index ["organisation_id"], name: "index_customer_discounts_on_organisation_id"
  end

  create_table "customer_product_discounts", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "product_id", null: false
    t.bigint "organisation_id", null: false
    t.decimal "discount_percentage", precision: 5, scale: 4, default: "0.0"
    t.date "valid_from"
    t.date "valid_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "discount_type", default: "percentage", null: false
    t.boolean "stackable", default: false, null: false
    t.boolean "active", default: true, null: false
    t.index ["customer_id"], name: "index_customer_product_discounts_on_customer_id"
    t.index ["organisation_id"], name: "index_customer_product_discounts_on_organisation_id"
    t.index ["product_id"], name: "index_customer_product_discounts_on_product_id"
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
    t.index ["email", "organisation_id"], name: "index_customers_on_email_and_organisation_id", unique: true
    t.index ["invitation_token"], name: "index_customers_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_customers_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_customers_on_invited_by"
    t.index ["locale"], name: "index_customers_on_locale"
    t.index ["organisation_id", "external_id", "external_source"], name: "index_customers_on_org_external_id_source", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["organisation_id"], name: "index_customers_on_organisation_id"
    t.index ["reset_password_token"], name: "index_customers_on_reset_password_token", unique: true
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
    t.index ["erp_configuration_id"], name: "index_erp_sync_logs_on_erp_configuration_id"
    t.index ["organisation_id", "created_at"], name: "index_erp_sync_logs_on_organisation_id_and_created_at"
    t.index ["organisation_id"], name: "index_erp_sync_logs_on_organisation_id"
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
    t.index ["applied_by_id"], name: "index_orders_on_applied_by_id"
    t.index ["billing_address_id"], name: "index_orders_on_billing_address_id"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["order_discount_id"], name: "index_orders_on_order_discount_id"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["organisation_id", "customer_id"], name: "index_orders_on_organisation_id_and_customer_id"
    t.index ["organisation_id", "placed_at"], name: "index_orders_on_organisation_id_and_placed_at"
    t.index ["organisation_id"], name: "index_orders_on_organisation_id"
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
    t.index ["invitation_token"], name: "index_org_members_on_invitation_token", unique: true
    t.index ["member_id"], name: "index_org_members_on_member_id"
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
    t.bigint "product_id", null: false
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
    t.boolean "track_stock", default: false, null: false
    t.boolean "available", default: true, null: false
    t.boolean "is_default", default: false, null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "external_id"
    t.string "external_source"
    t.datetime "last_synced_at"
    t.text "sync_error"
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
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["organisation_id", "external_id", "external_source"], name: "index_products_on_org_external_id_source", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["organisation_id"], name: "index_products_on_organisation_id"
    t.index ["slug"], name: "index_products_on_slug", unique: true
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
  add_foreign_key "categories", "organisations"
  add_foreign_key "category_products", "categories"
  add_foreign_key "category_products", "products"
  add_foreign_key "customer_discounts", "customers"
  add_foreign_key "customer_discounts", "organisations"
  add_foreign_key "customer_product_discounts", "customers"
  add_foreign_key "customer_product_discounts", "organisations"
  add_foreign_key "customer_product_discounts", "products"
  add_foreign_key "customers", "organisations"
  add_foreign_key "erp_configurations", "organisations"
  add_foreign_key "erp_sync_logs", "erp_configurations"
  add_foreign_key "erp_sync_logs", "organisations"
  add_foreign_key "order_discounts", "organisations"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "product_variants"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "addresses", column: "billing_address_id"
  add_foreign_key "orders", "addresses", column: "shipping_address_id"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "members", column: "applied_by_id"
  add_foreign_key "orders", "order_discounts"
  add_foreign_key "orders", "organisations"
  add_foreign_key "org_members", "members"
  add_foreign_key "org_members", "organisations"
  add_foreign_key "product_attribute_values", "product_attributes"
  add_foreign_key "product_attributes", "organisations"
  add_foreign_key "product_available_values", "product_attribute_values"
  add_foreign_key "product_available_values", "products"
  add_foreign_key "product_discounts", "organisations"
  add_foreign_key "product_discounts", "products"
  add_foreign_key "product_product_attributes", "product_attributes"
  add_foreign_key "product_product_attributes", "products"
  add_foreign_key "product_variants", "organisations"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "categories"
  add_foreign_key "products", "organisations"
  add_foreign_key "variant_attribute_values", "product_attribute_values"
  add_foreign_key "variant_attribute_values", "product_variants"
end
