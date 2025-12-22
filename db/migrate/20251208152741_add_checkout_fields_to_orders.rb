class AddCheckoutFieldsToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :tax_amount_cents, :integer
    add_column :orders, :tax_amount_currency, :string
    add_column :orders, :shipping_amount_cents, :integer
    add_column :orders, :shipping_amount_currency, :string
    add_column :orders, :delivery_method, :string, default: "delivery"
  end
end
