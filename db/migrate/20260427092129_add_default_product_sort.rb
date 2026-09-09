class AddDefaultProductSort < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :default_product_sort, :string, default: "name_asc", null: false
    add_column :categories, :default_product_sort, :string
  end
end
