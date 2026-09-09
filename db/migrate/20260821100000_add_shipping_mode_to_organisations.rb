class AddShippingModeToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :shipping_mode, :string, default: "fixed", null: false

    # Snapshot taken when the order is placed: were the shipping costs still to
    # be determined at that moment? Stored on the order rather than derived from
    # the organisation so that flipping the setting later never rewrites the
    # totals of orders that were already placed.
    add_column :orders, :shipping_pending, :boolean, default: false, null: false
  end
end
