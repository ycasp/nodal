class AddDisplayTypeToProductAttributes < ActiveRecord::Migration[7.1]
  def change
    add_column :product_attributes, :display_type, :string, default: "dropdown", null: false
  end
end
