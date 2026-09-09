class AddConditionScopeToDiscounts < ActiveRecord::Migration[7.1]
  def change
    # per_line: the condition is checked on each line on its own (current).
    # summed:   checked on the combined total across the discount's target
    #           (a product's variants, or all products in a category).
    add_column :product_discounts, :condition_scope, :string, null: false, default: "per_line"
    add_column :customer_product_discounts, :condition_scope, :string, null: false, default: "per_line"
  end
end
