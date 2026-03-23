class AddCategoryToCustomerProductDiscounts < ActiveRecord::Migration[7.1]
  def change
    add_reference :customer_product_discounts, :category, null: true, foreign_key: true
    change_column_null :customer_product_discounts, :product_id, true
  end
end
