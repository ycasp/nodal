class BackfillProductRichDescription < ActiveRecord::Migration[7.1]
  def up
    Product.find_each do |product|
      next if product.description.blank?
      next if product.rich_description.body.present?

      product.rich_description = product.description
      product.save!(validate: false)
    end
  end

  def down
    # Non-reversible: data is preserved in the description column.
  end
end
