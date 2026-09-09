class CreateHomepageFeaturedProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :homepage_featured_products do |t|
      t.references :organisation, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :position

      t.timestamps
    end
    add_index :homepage_featured_products, [:organisation_id, :product_id], unique: true, name: 'idx_homepage_featured_products_unique'
  end
end
