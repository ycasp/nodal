class AddProductSyncModeToErpConfigurations < ActiveRecord::Migration[7.1]
  def change
    add_column :erp_configurations, :product_sync_mode, :string, default: 'update_only'
  end
end
