class CreateShoppingLists < ActiveRecord::Migration[7.1]
  def change
    create_table :shopping_lists do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :organisation, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :shopping_lists, [:customer_id, :organisation_id]
  end
end
