class AddHideWhenUnavailableToProductVariants < ActiveRecord::Migration[7.1]
  def change
    add_column :product_variants, :hide_when_unavailable, :boolean, default: true, null: false
  end
end
