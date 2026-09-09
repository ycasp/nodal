class AddRelatedProductsSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :show_related_products, :boolean, default: true, null: false
    add_column :products, :hide_related_products, :boolean, default: false, null: false
  end
end
