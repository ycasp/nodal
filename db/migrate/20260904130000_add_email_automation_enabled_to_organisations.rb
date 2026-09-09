class AddEmailAutomationEnabledToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :email_automation_enabled, :boolean, null: false, default: true
  end
end
