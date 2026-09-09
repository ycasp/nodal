class AddErpSyncableToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :external_id, :string
    add_column :orders, :external_source, :string
    add_column :orders, :last_synced_at, :datetime
    add_column :orders, :sync_error, :text
    add_index :orders, [:organisation_id, :external_id, :external_source],
              unique: true,
              where: "external_id IS NOT NULL",
              name: "index_orders_on_org_external_id_source"
  end
end
