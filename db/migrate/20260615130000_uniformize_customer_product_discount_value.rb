class UniformizeCustomerProductDiscountValue < ActiveRecord::Migration[7.1]
  def up
    # Align with the other discount models: a single `discount_value` column
    # with enough precision to hold fixed amounts (was decimal(5,4), capping
    # fixed discounts at 9.9999).
    rename_column :customer_product_discounts, :discount_percentage, :discount_value
    change_column :customer_product_discounts, :discount_value, :decimal, precision: 10, scale: 4, default: "0.0"
  end

  def down
    change_column :customer_product_discounts, :discount_value, :decimal, precision: 5, scale: 4, default: "0.0"
    rename_column :customer_product_discounts, :discount_value, :discount_percentage
  end
end
