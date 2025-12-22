class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  monetize :unit_price, as: :price

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percentage, numericality: { greater_than_or_equal_to: 0,
     less_than_or_equal_to: 1 }, allow_nil: true

  before_validation :set_unit_price_from_product, on: :create
  before_validation :recalculate_discount, if: :should_recalculate_discount?

  def total_price
    subtotal = price * quantity
    discount = subtotal * (discount_percentage || 0)
    return subtotal - discount
  end

  private

  def set_unit_price_from_product
    self.unit_price ||= product&.unit_price
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
      quantity: quantity || 1
    )

    self.discount_percentage = calculator.effective_discount[:percentage] || 0
  end
end
