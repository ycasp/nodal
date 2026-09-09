class BackfillCustomerUsers < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  class MigrationCustomer < ActiveRecord::Base
    self.table_name = "customers"
  end

  class MigrationCustomerUser < ActiveRecord::Base
    self.table_name = "customer_users"
  end

  class MigrationOrder < ActiveRecord::Base
    self.table_name = "orders"
  end

  def up
    MigrationCustomer.find_each do |customer|
      next if MigrationCustomerUser.exists?(customer_id: customer.id)

      cu = MigrationCustomerUser.create!(
        customer_id: customer.id,
        organisation_id: customer.organisation_id,
        email: customer.email.to_s,
        encrypted_password: customer.encrypted_password.to_s,
        reset_password_token: customer.reset_password_token,
        reset_password_sent_at: customer.reset_password_sent_at,
        remember_created_at: customer.remember_created_at,
        invitation_token: customer.invitation_token,
        invitation_created_at: customer.invitation_created_at,
        invitation_sent_at: customer.invitation_sent_at,
        invitation_accepted_at: customer.invitation_accepted_at,
        invitation_limit: customer.invitation_limit,
        invited_by_type: customer.invited_by_type,
        invited_by_id: customer.invited_by_id,
        invitations_count: customer.invitations_count || 0,
        sign_in_count: customer.sign_in_count || 0,
        current_sign_in_at: customer.current_sign_in_at,
        last_sign_in_at: customer.last_sign_in_at,
        current_sign_in_ip: customer.current_sign_in_ip,
        last_sign_in_ip: customer.last_sign_in_ip,
        contact_name: customer.contact_name,
        contact_phone: customer.contact_phone,
        locale: customer.locale,
        email_notifications_enabled: customer.email_notifications_enabled.nil? ? true : customer.email_notifications_enabled,
        hide_prices: customer.hide_prices.nil? ? false : customer.hide_prices,
        active: customer.active.nil? ? true : customer.active,
        created_at: customer.created_at,
        updated_at: customer.updated_at
      )

      MigrationOrder.where(customer_id: customer.id, customer_user_id: nil).update_all(customer_user_id: cu.id)
    end
  end

  def down
    MigrationOrder.where.not(customer_user_id: nil).update_all(customer_user_id: nil)
    MigrationCustomerUser.delete_all
  end
end
