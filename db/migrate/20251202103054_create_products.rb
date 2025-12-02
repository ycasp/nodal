class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.references :organisation, null: false, foreign_key: true
      t.string :name
      t.string :slug, null: false
      t.string :sku
      t.text :description
      t.integer :unit_price
      t.string :unit_description
      t.integer :min_quantity
      t.string :min_quantity_type
      t.boolean :available, default: true, null: false
      t.references :category, null: false, foreign_key: true
      t.json :product_attributes

      t.timestamps
    end

    add_index :products, :slug, unique: true
  end
end
