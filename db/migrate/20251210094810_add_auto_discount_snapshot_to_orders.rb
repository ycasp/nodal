class AddAutoDiscountSnapshotToOrders < ActiveRecord::Migration[7.1]
  def change
    add_reference :orders, :order_discount, foreign_key: true, null: true
    add_column :orders, :auto_discount_type, :string
    add_column :orders, :auto_discount_value, :decimal, precision: 10, scale: 4
    add_column :orders, :auto_discount_amount_cents, :integer
  end
end
