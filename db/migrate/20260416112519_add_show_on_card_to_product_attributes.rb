class AddShowOnCardToProductAttributes < ActiveRecord::Migration[7.1]
  def change
    add_column :product_attributes, :show_on_card, :boolean, default: false, null: false
  end
end
