class AddAddressesToOrders < ActiveRecord::Migration[7.1]
  def change
    add_reference :orders, :shipping_address, foreign_key: { to_table: :addresses }
    add_reference :orders, :billing_address, foreign_key: { to_table: :addresses }
  end
end
