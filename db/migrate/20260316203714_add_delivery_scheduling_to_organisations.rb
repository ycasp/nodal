class AddDeliverySchedulingToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :delivery_days, :integer, default: 62, null: false
    add_column :organisations, :order_cutoff_time, :string
    add_column :organisations, :lead_time_days, :integer, default: 1, null: false
    add_column :organisations, :timezone, :string, default: "Europe/Lisbon", null: false
  end
end
