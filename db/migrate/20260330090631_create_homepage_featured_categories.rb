class CreateHomepageFeaturedCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :homepage_featured_categories do |t|
      t.references :organisation, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.integer :position

      t.timestamps
    end
    add_index :homepage_featured_categories, [:organisation_id, :category_id], unique: true, name: 'idx_homepage_featured_categories_unique'
  end
end
