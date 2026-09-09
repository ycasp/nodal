class FixRelatedProductForeignKey < ActiveRecord::Migration[7.1]
  def change
    # Remove incorrect foreign key that points to related_products table
    remove_foreign_key :related_products, :related_products, if_exists: true

    # Add correct foreign key that points to products table
    add_foreign_key :related_products, :products, column: :related_product_id, if_not_exists: true
  end
end
