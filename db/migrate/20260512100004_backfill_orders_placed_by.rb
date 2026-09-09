class BackfillOrdersPlacedBy < ActiveRecord::Migration[7.1]
  # Historical orders pre-date the sales-rep feature. We can't distinguish
  # self-service from BO-created in existing data, so we assume self-service
  # via the customer_user_id that was backfilled during the Customer Users
  # refactor (PR #113). The handful of historical BO-created orders will be
  # mis-attributed to CustomerUser — acceptable historical noise.
  #
  # New orders from this PR onward set placed_by explicitly at create time.
  def up
    execute <<~SQL.squish
      UPDATE orders
      SET placed_by_type = 'CustomerUser',
          placed_by_id = customer_user_id
      WHERE customer_user_id IS NOT NULL
        AND placed_by_type IS NULL
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE orders
      SET placed_by_type = NULL,
          placed_by_id = NULL
      WHERE placed_by_type = 'CustomerUser'
    SQL
  end
end
