class AddCampaignColorToOrganisations < ActiveRecord::Migration[7.1]
  def change
    # Storefront accent colour for the "Campanhas" discovery entry. Nil falls
    # back to red (#dc3545) via Organisation#effective_campaign_color.
    add_column :organisations, :campaign_color, :string
  end
end
