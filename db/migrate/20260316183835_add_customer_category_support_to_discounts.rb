class AddCustomerCategorySupportToDiscounts < ActiveRecord::Migration[7.1]
  def change
    # customer_discounts: add customer_category_id, make customer_id nullable
    change_column_null :customer_discounts, :customer_id, true
    add_reference :customer_discounts, :customer_category, foreign_key: true, null: true

    # customer_product_discounts: same
    change_column_null :customer_product_discounts, :customer_id, true
    add_reference :customer_product_discounts, :customer_category, foreign_key: true, null: true

    # promo_code_customer_categories join table
    create_table :promo_code_customer_categories do |t|
      t.references :promo_code, null: false, foreign_key: true
      t.references :customer_category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :promo_code_customer_categories, [:promo_code_id, :customer_category_id],
              unique: true, name: 'idx_promo_code_customer_categories_unique'
  end
end
