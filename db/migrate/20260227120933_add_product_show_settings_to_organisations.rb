class AddProductShowSettingsToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :show_product_sku, :boolean, default: true, null: false
    add_column :organisations, :show_product_min_quantity, :boolean, default: true, null: false
    add_column :organisations, :show_product_category, :boolean, default: true, null: false
    add_column :organisations, :show_product_availability, :boolean, default: true, null: false
  end
end
