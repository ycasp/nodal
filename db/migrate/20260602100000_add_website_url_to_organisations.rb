class AddWebsiteUrlToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :website_url, :string
  end
end
