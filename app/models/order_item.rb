class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  monetize :unit_price, as: :price

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percentage, numericality: { greater_than_or_equal_to: 0,
     less_than_or_equal_to: 1 }, allow_nil: true

  before_validation :set_unit_price_from_product, on: :create

  def total_price
    subtotal = price * quantity
    discount = subtotal * (discount_percentage || 0)
    return subtotal - discount
  end

  private

  def set_unit_price_from_product
    self.unit_price ||= product&.unit_price
  end
end
