class AddShowSaleBadgeToOrganisations < ActiveRecord::Migration[7.1]
  def change
    # Storefront-wide switch for the promotion ("PROMOÇÃO/SALE") badge. When
    # false the badge never renders anywhere (product cards, product page,
    # homepage cards) regardless of text/colour. Defaults on = current behaviour.
    add_column :organisations, :show_sale_badge, :boolean, default: true, null: false
  end
end
