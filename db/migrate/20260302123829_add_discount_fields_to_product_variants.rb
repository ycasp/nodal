class AddDiscountFieldsToProductVariants < ActiveRecord::Migration[7.1]
  def change
    add_column :product_variants, :exclude_from_discounts, :boolean, default: false, null: false
    add_column :product_variants, :custom_discount_type, :string
    add_column :product_variants, :custom_discount_value, :decimal, precision: 10, scale: 4
  end
end
