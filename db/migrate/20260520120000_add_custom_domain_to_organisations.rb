class AddCustomDomainToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :custom_domain, :string
    add_column :organisations, :custom_domain_verified_at, :datetime

    add_index :organisations,
              :custom_domain,
              unique: true,
              where: "custom_domain IS NOT NULL",
              name: "index_organisations_on_custom_domain"
  end
end
