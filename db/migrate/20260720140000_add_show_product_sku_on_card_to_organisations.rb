class AddShowProductSkuOnCardToOrganisations < ActiveRecord::Migration[7.1]
  def change
    # Org-level default for showing the product SKU on storefront listing cards.
    # Opt-in (off by default). A product can still suppress it per-product via
    # products.hide_sku_on_card. Distinct from show_product_sku, which controls
    # the SKU on the product detail page.
    add_column :organisations, :show_product_sku_on_card, :boolean, default: false, null: false
  end
end
