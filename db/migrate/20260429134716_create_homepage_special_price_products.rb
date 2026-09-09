class CreateHomepageSpecialPriceProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :homepage_special_price_products do |t|
      t.references :organisation, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :position

      t.timestamps
    end
  end
end
