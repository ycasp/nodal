class AddDashboardPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # Index for filtering orders by organisation and placed_at date range
    add_index :orders, [:organisation_id, :placed_at],
              name: "index_orders_on_organisation_id_and_placed_at"

    # Index for customer sales queries
    add_index :orders, [:organisation_id, :customer_id],
              name: "index_orders_on_organisation_id_and_customer_id"

    # Index for product revenue queries
    add_index :order_items, [:order_id, :product_id],
              name: "index_order_items_on_order_id_and_product_id"
  end
end
