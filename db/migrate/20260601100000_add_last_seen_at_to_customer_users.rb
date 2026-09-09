class AddLastSeenAtToCustomerUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :customer_users, :last_seen_at, :datetime
    add_index :customer_users, :last_seen_at
  end
end
