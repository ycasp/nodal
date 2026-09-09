class AddConditionToCustomerProductDiscounts < ActiveRecord::Migration[7.1]
  def change
    # Custom prices had no threshold; allow an optional quantity or € minimum.
    add_column :customer_product_discounts, :condition_type, :string, null: false, default: "none"
    add_column :customer_product_discounts, :min_quantity, :integer
    add_column :customer_product_discounts, :min_amount_cents, :integer
  end
end
