class AddDiscountToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :discount_type, :string
    add_column :orders, :discount_value, :decimal, precision: 10, scale: 4
    add_column :orders, :discount_reason, :text
    add_reference :orders, :applied_by, foreign_key: { to_table: :members }
  end
end
