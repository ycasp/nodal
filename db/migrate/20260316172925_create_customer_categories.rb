class CreateCustomerCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_categories do |t|
      t.references :organisation, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.timestamps
    end
    add_index :customer_categories, [:organisation_id, :name], unique: true
    add_reference :customers, :customer_category, foreign_key: true, null: true
  end
end
