class AddHidePricesToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :hide_prices, :boolean, default: false, null: false
  end
end
