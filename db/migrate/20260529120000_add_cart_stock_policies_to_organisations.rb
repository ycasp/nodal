class AddCartStockPoliciesToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :cart_stock_policy, :string, null: false, default: "warn"
    add_column :organisations, :cart_qty_overflow_policy, :string, null: false, default: "warn"
  end
end
