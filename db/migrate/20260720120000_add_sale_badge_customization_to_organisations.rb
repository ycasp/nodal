class AddSaleBadgeCustomizationToOrganisations < ActiveRecord::Migration[7.1]
  def change
    # Custom label for the storefront "PROMOÇÃO/SALE" badge. NULL/blank falls
    # back to the translated default (storefront.products.index.sale_badge).
    add_column :organisations, :sale_badge_text, :string

    # Background colour for the same badge. NULL/blank falls back to #dc3545
    # (the current red) via Organisation#effective_sale_badge_color.
    add_column :organisations, :sale_badge_color, :string
  end
end
