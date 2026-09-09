class AddSpecialPriceCardTogglesToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :special_prices_show_price, :boolean, default: true, null: false
    add_column :organisations, :special_prices_show_discount_badge, :boolean, default: true, null: false
    add_column :organisations, :special_prices_show_sale_badge, :boolean, default: true, null: false
  end
end
