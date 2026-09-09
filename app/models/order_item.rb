class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product
  belongs_to :product_variant, optional: true

  monetize :unit_price, as: :price

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percentage, numericality: { greater_than_or_equal_to: 0,
     less_than_or_equal_to: 1 }, allow_nil: true
  validate :variant_belongs_to_product
  validate :variant_is_purchasable, on: :create

  before_validation :set_variant_for_simple_product, on: :create
  before_validation :set_unit_price_from_variant, on: :create
  before_validation :recalculate_discount, if: :should_recalculate_discount?

  def total_price
    subtotal = price * quantity
    discount = subtotal * (discount_percentage || 0)
    return subtotal - discount
  end

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

  def set_unit_price_from_variant
    return if unit_price.present?

    self.unit_price = product_variant&.unit_price_cents || product&.unit_price
  end

  def variant_belongs_to_product
    return if product_variant.nil? || product.nil?

    unless product_variant.product_id == product.id
      errors.add(:product_variant, "must belong to the selected product")
    end
  end

  def variant_is_purchasable
    return if product_variant.nil?

    unless product_variant.purchasable?
      errors.add(:product_variant, "is not available for purchase")
    end
  end

  def should_recalculate_discount?
    # Recalculate on create, or when quantity changes (for min_quantity thresholds)
    new_record? || quantity_changed?
  end

  def recalculate_discount
    # Use DiscountCalculator to get effective discount from ALL sources:
    # - ProductDiscount (product-level sales, may have min_quantity)
    # - CustomerDiscount (client tier discounts)
    # - CustomerProductDiscount (custom pricing)
    calculator = DiscountCalculator.new(
      product: product,
      customer: order&.customer,
      quantity: quantity || 1,
      variant: product_variant
    )

    self.discount_percentage = calculator.effective_discount[:percentage] || 0
  end
end
