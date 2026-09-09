class AddConditionToProductDiscounts < ActiveRecord::Migration[7.1]
  def change
    # condition_type: 'quantity' (use min_quantity) | 'amount' (use min_amount_cents) | 'none'
    add_column :product_discounts, :condition_type, :string, null: false, default: "quantity"
    add_column :product_discounts, :min_amount_cents, :integer
  end
end
