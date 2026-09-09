class AddStorefrontDescriptionToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :storefront_description, :text
  end
end
