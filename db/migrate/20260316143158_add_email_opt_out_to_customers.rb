class AddEmailOptOutToCustomers < ActiveRecord::Migration[7.1]
  def change
    add_column :customers, :email_notifications_enabled, :boolean, default: true, null: false
  end
end
