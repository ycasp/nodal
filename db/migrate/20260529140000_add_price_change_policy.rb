class AddPriceChangePolicy < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :cart_price_change_policy, :string, null: false, default: "notify"
    add_column :orders, :pricing_changed_at, :datetime
  end
end
