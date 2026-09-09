class AddErpTrackingToAddresses < ActiveRecord::Migration[7.1]
  def change
    add_column :addresses, :external_source, :string
    add_column :addresses, :external_id, :string
    add_column :addresses, :last_synced_at, :datetime

    add_index :addresses,
              [:addressable_type, :addressable_id, :external_source],
              name: "idx_addresses_on_addressable_and_source"
  end
end
