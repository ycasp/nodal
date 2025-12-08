class AddTaxAndShippingToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :tax_rate, :decimal, precision: 5, scale: 4, default: 0.08
    add_column :organisations, :shipping_cost_cents, :integer, default: 1500
    add_column :organisations, :shipping_cost_currency, :string, default: "EUR"
  end
end
