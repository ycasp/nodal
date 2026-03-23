class CreateShoppingListItems < ActiveRecord::Migration[7.1]
  def change
    create_table :shopping_list_items do |t|
      t.references :shopping_list, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.integer :quantity, default: 1, null: false

      t.timestamps
    end

    add_index :shopping_list_items, [:shopping_list_id, :product_id, :product_variant_id],
              unique: true, name: :idx_shopping_list_items_uniqueness
  end
end
