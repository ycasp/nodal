class CreateCustomerDiscounts < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_discounts do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :organisation, null: false, foreign_key: true
      t.string :discount_type, default: 'percentage', null: false
      t.decimal :discount_value, precision: 10, scale: 4, null: false
      t.date :valid_from
      t.date :valid_until
      t.boolean :stackable, default: false, null: false
      t.boolean :active, default: true, null: false
      t.text :notes

      t.timestamps
    end

    add_index :customer_discounts, [:customer_id, :organisation_id]
  end
end
