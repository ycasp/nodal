class UpdateCustomerProductDiscounts < ActiveRecord::Migration[7.1]
  def change
    add_column :customer_product_discounts, :discount_type, :string, default: 'percentage', null: false
    add_column :customer_product_discounts, :stackable, :boolean, default: false, null: false
    add_column :customer_product_discounts, :active, :boolean, default: true, null: false
  end
end
