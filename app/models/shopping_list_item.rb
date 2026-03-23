class ShoppingListItem < ApplicationRecord
  belongs_to :shopping_list, touch: true
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validate :variant_belongs_to_product

  before_validation :set_variant_for_simple_product, on: :create

  def variant_name
    product_variant&.option_values_string.presence || product&.name
  end

  def effective_photo
    product_variant&.effective_photo || (product&.photo_attached? ? product.photo : nil)
  end

  private

  def set_variant_for_simple_product
    return if product_variant.present?
    return unless product.present?

    self.product_variant = product.default_variant
  end

  def variant_belongs_to_product
    return if product_variant.nil? || product.nil?

    unless product_variant.product_id == product.id
      errors.add(:product_variant, "must belong to the selected product")
    end
  end
end
