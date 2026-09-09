class AddHeroFieldsToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :hero_title, :string
    add_column :organisations, :hero_subtitle, :string
    add_column :organisations, :hero_link_url, :string
    add_column :organisations, :hero_link_text, :string
  end
end
