class AddSocialLinksToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :instagram_url, :string
    add_column :organisations, :facebook_url, :string
    add_column :organisations, :linkedin_url, :string
  end
end
