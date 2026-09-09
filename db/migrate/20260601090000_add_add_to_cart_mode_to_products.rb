class AddAddToCartModeToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :add_to_cart_mode, :string, null: false, default: "default"
  end
end
