class AddReceiveOrderNotificationsToOrgMembers < ActiveRecord::Migration[7.1]
  def change
    add_column :org_members, :receive_order_notifications, :boolean, default: false, null: false
  end
end
