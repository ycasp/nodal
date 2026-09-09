class MakeOrdersCustomerUserIdNotNull < ActiveRecord::Migration[7.1]
  # Defensive backfill + NOT NULL. Run together so we never leave the
  # column half-constrained. Idempotent — re-runs are safe.
  def up
    # Attach any stranded orders (e.g. checkouts that landed mid-deploy
    # of PR 2 before storefront started populating customer_user_id) to
    # the first CustomerUser of their Customer.
    execute <<~SQL.squish
      UPDATE orders o
      SET customer_user_id = cu.id
      FROM customer_users cu
      WHERE o.customer_id IS NOT NULL
        AND o.customer_user_id IS NULL
        AND cu.customer_id = o.customer_id
        AND cu.id = (
          SELECT MIN(id) FROM customer_users WHERE customer_id = o.customer_id
        )
    SQL

    change_column_null :orders, :customer_user_id, false
  end

  def down
    change_column_null :orders, :customer_user_id, true
  end
end
