class AddViewedAtToOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :orders, :viewed_at, :datetime

    reversible do |dir|
      dir.up do
        Order.where.not(placed_at: nil).update_all(viewed_at: Time.current)
      end
    end
  end
end
