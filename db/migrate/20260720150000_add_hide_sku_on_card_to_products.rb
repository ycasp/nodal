class AddHideSkuOnCardToProducts < ActiveRecord::Migration[7.1]
  def change
    # Per-product override to suppress the listing-card SKU even when the org
    # has it enabled (mirrors the hide_related_products pattern).
    add_column :products, :hide_sku_on_card, :boolean, default: false, null: false
  end
end
