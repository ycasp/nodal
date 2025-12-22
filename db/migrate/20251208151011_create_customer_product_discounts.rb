class CreateCustomerProductDiscounts < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_product_discounts do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :organisation, null: false, foreign_key: true
      t.decimal :discount_percentage, precision: 5, scale: 4, default: 0
      t.date :valid_from
      t.date :valid_until

      t.timestamps
    end
  end
end
