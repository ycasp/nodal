class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_validation :set_unit_price_from_product, on: :create

  def total_price
    (unit_price * quantity) - (discount_amount || 0)
  end

  private

  def set_unit_price_from_product
    self.unit_price ||= product&.unit_price
  end
end
