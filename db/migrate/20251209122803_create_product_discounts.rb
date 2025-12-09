class CreateProductDiscounts < ActiveRecord::Migration[7.1]
  def change
    create_table :product_discounts do |t|
      t.references :product, null: false, foreign_key: true
      t.references :organisation, null: false, foreign_key: true
      t.string :discount_type, default: 'percentage', null: false
      t.decimal :discount_value, precision: 10, scale: 4, null: false
      t.integer :min_quantity, default: 1, null: false
      t.date :valid_from
      t.date :valid_until
      t.boolean :stackable, default: false, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :product_discounts, [:product_id, :organisation_id]
  end
end
