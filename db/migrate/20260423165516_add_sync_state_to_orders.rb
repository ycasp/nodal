class AddSyncStateToOrders < ActiveRecord::Migration[7.1]
  def up
    add_column :orders, :push_status, :string, default: "pending", null: false
    add_column :orders, :push_attempts, :integer, default: 0, null: false
    add_column :orders, :last_pushed_at, :datetime

    add_index :orders, [:organisation_id, :push_status]

    execute <<~SQL
      UPDATE orders SET push_status = 'synced'
      WHERE external_id IS NOT NULL AND external_source IS NOT NULL
    SQL
  end

  def down
    remove_column :orders, :last_pushed_at
    remove_column :orders, :push_attempts
    remove_column :orders, :push_status
  end
end
