class AddEmailPrefsToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :email_order_confirmation_enabled, :boolean, default: true, null: false
    add_column :organisations, :email_discount_notification_enabled, :boolean, default: true, null: false
    add_column :organisations, :email_customer_invitation_enabled, :boolean, default: true, null: false
    add_column :organisations, :email_member_order_notification_enabled, :boolean, default: true, null: false
  end
end
