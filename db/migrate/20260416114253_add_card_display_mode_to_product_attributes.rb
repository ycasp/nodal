class AddCardDisplayModeToProductAttributes < ActiveRecord::Migration[7.1]
  def change
    add_column :product_attributes, :card_display_mode, :string, default: "values", null: false
  end
end
