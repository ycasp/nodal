class AddShowWhatsappButtonToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :show_whatsapp_button, :boolean, default: false, null: false
  end
end
