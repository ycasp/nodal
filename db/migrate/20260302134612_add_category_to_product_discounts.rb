class AddCategoryToProductDiscounts < ActiveRecord::Migration[7.1]
  def change
    add_reference :product_discounts, :category, null: true, foreign_key: true
    change_column_null :product_discounts, :product_id, true
  end
end
