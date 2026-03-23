class CreatePromoCodesAndRelatedTables < ActiveRecord::Migration[7.1]
  def change
    create_table :promo_codes do |t|
      t.references :organisation, null: false, foreign_key: true
      t.string :code, null: false
      t.text :description
      t.string :discount_type, null: false
      t.decimal :discount_value, precision: 10, scale: 4, null: false
      t.integer :min_order_amount_cents, default: 0
      t.integer :usage_limit
      t.integer :usage_count, default: 0, null: false
      t.integer :per_customer_limit, default: 1, null: false
      t.string :eligibility, default: 'all_customers', null: false
      t.date :valid_from
      t.date :valid_until
      t.boolean :stackable, default: false, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :promo_codes, [:organisation_id, :code], unique: true

    create_table :promo_code_customers do |t|
      t.references :promo_code, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.timestamps
    end

    add_index :promo_code_customers, [:promo_code_id, :customer_id], unique: true

    create_table :promo_code_redemptions do |t|
      t.references :promo_code, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.integer :discount_amount_cents, null: false
      t.timestamps
    end

    add_reference :orders, :promo_code, foreign_key: true, null: true
    add_column :orders, :promo_code_discount_amount_cents, :integer, default: 0
  end
end
