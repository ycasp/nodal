class RemoveHeroFieldsFromOrganisations < ActiveRecord::Migration[7.1]
  def change
    remove_column :organisations, :hero_title, :string
    remove_column :organisations, :hero_subtitle, :string
    remove_column :organisations, :hero_link_url, :string
    remove_column :organisations, :hero_link_text, :string
    remove_column :products, :featured, :boolean, default: false, null: false
  end
end
