class CreateOrderDiscounts < ActiveRecord::Migration[7.1]
  def change
    create_table :order_discounts do |t|
      t.references :organisation, null: false, foreign_key: true
      t.string :discount_type, null: false
      t.decimal :discount_value, precision: 10, scale: 4, null: false
      t.integer :min_order_amount_cents, null: false
      t.date :valid_from
      t.date :valid_until
      t.boolean :stackable, default: false
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :order_discounts, [:organisation_id, :active]
  end
end
