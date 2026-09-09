class AddVisibilityAndNavStyleToCategories < ActiveRecord::Migration[7.1]
  def change
    add_column :categories, :published, :boolean, default: true, null: false
    add_column :categories, :nav_bold, :boolean, default: false, null: false
    add_column :categories, :nav_italic, :boolean, default: false, null: false

    add_index :categories, [:organisation_id, :published]
  end
end
