class AddCurrencyToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :currency, :string, default: 'EUR', null: false
  end
end
