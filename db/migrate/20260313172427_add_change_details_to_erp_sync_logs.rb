class AddChangeDetailsToErpSyncLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :erp_sync_logs, :change_details, :jsonb, default: []
  end
end
