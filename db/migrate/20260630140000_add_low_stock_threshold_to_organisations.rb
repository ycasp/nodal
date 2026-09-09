class AddLowStockThresholdToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :low_stock_threshold, :integer, default: 5, null: false
  end
end
