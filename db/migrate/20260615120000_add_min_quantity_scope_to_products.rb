class AddMinQuantityScopeToProducts < ActiveRecord::Migration[7.1]
  def change
    # per_variant: each variant line must meet the minimum on its own (current behaviour)
    # combined:    the minimum is the sum of the product's variants in the cart
    add_column :products, :min_quantity_scope, :string, null: false, default: "per_variant"
  end
end
