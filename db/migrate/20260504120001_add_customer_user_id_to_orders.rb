class AddCustomerUserIdToOrders < ActiveRecord::Migration[7.1]
  def change
    add_reference :orders, :customer_user, foreign_key: true, null: true
  end
end
