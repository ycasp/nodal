class AddPriceOnRequestToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :price_on_request, :boolean, default: false, null: false
  end
end
