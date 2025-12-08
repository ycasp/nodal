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

ActiveRecord::Schema[7.1].define(version: 2025_12_08_151011) do
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
    t.index ["addressable_type", "addressable_id"], name: "index_addresses_on_addressable"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.bigint "organisation_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organisation_id"], name: "index_categories_on_organisation_id"
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
    t.index ["email", "organisation_id"], name: "index_customers_on_email_and_organisation_id", unique: true
    t.index ["invitation_token"], name: "index_customers_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_customers_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_customers_on_invited_by"
    t.index ["organisation_id"], name: "index_customers_on_organisation_id"
    t.index ["reset_password_token"], name: "index_customers_on_reset_password_token", unique: true
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
    t.index ["email"], name: "index_members_on_email", unique: true
    t.index ["reset_password_token"], name: "index_members_on_reset_password_token", unique: true
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.integer "unit_price", null: false
    t.decimal "discount_percentage", precision: 5, scale: 4, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
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
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["organisation_id"], name: "index_orders_on_organisation_id"
  end

  create_table "org_members", force: :cascade do |t|
    t.bigint "organisation_id", null: false
    t.bigint "member_id", null: false
    t.string "role"
    t.datetime "joined_at"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["slug"], name: "index_organisations_on_slug", unique: true
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
    t.bigint "category_id", null: false
    t.json "product_attributes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["organisation_id"], name: "index_products_on_organisation_id"
    t.index ["slug"], name: "index_products_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "categories", "organisations"
  add_foreign_key "customer_product_discounts", "customers"
  add_foreign_key "customer_product_discounts", "organisations"
  add_foreign_key "customer_product_discounts", "products"
  add_foreign_key "customers", "organisations"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "customers"
  add_foreign_key "orders", "organisations"
  add_foreign_key "org_members", "members"
  add_foreign_key "org_members", "organisations"
  add_foreign_key "products", "categories"
  add_foreign_key "products", "organisations"
end
