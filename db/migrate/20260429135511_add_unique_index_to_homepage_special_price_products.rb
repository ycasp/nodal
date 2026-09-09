class AddUniqueIndexToHomepageSpecialPriceProducts < ActiveRecord::Migration[7.1]
  def change
    add_index :homepage_special_price_products,
              [:organisation_id, :product_id],
              unique: true,
              name: "index_special_price_products_on_org_and_product"
  end
end
