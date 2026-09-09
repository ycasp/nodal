class AddCheckoutStockPolicyToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :checkout_stock_policy, :string, null: false, default: "warn"
  end
end
