class AddPlacedByAndSalesRepToOrders < ActiveRecord::Migration[7.1]
  def change
    add_reference :orders, :placed_by, polymorphic: true, null: true, index: true

    add_reference :orders, :sales_rep,
                  foreign_key: { to_table: :org_members },
                  null: true,
                  index: true
  end
end
