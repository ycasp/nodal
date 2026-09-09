class FixEmailNotificationsEnabledDefault < ActiveRecord::Migration[7.1]
  def up
    # Backfill existing customers
    Customer.where(email_notifications_enabled: [nil, false]).update_all(email_notifications_enabled: true)

    # Set proper default and not-null constraint
    change_column_default :customers, :email_notifications_enabled, true
    change_column_null :customers, :email_notifications_enabled, false, true

    # Same fix for org email toggles (may have run without defaults)
    %i[email_order_confirmation_enabled email_discount_notification_enabled
       email_customer_invitation_enabled email_member_order_notification_enabled].each do |col|
      if column_exists?(:organisations, col)
        Organisation.where(col => nil).update_all(col => true)
        change_column_default :organisations, col, true
        change_column_null :organisations, col, false, true
      end
    end
  end

  def down
    change_column_null :customers, :email_notifications_enabled, true
    change_column_default :customers, :email_notifications_enabled, nil

    %i[email_order_confirmation_enabled email_discount_notification_enabled
       email_customer_invitation_enabled email_member_order_notification_enabled].each do |col|
      if column_exists?(:organisations, col)
        change_column_null :organisations, col, true
        change_column_default :organisations, col, nil
      end
    end
  end
end
