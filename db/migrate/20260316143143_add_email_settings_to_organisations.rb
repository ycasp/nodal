class AddEmailSettingsToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :email_sender_name, :string
    add_column :organisations, :email_reply_to, :string
  end
end
