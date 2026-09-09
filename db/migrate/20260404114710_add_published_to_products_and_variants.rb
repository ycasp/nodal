class AddPublishedToProductsAndVariants < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :published, :boolean, default: true, null: false
    add_column :product_variants, :published, :boolean, default: true, null: false

    # Fix hide_when_unavailable: original migration had default: true but schema lost it
    change_column_default :product_variants, :hide_when_unavailable, from: nil, to: true
    ProductVariant.where(hide_when_unavailable: nil).update_all(hide_when_unavailable: true)
    change_column_null :product_variants, :hide_when_unavailable, false, true
  end
end
