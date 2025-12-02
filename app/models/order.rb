class Order < ApplicationRecord
  STATUSES = %w[in_process processed completed].freeze
  PAYMENT_STATUSES = %w[pending paid failed refunded].freeze

  belongs_to :customer
  belongs_to :organisation
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  validates :order_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }

  before_validation :generate_order_number, on: :create

  def total_amount
    order_items.sum { |item| (item.unit_price * item.quantity) - (item.discount_amount || 0) }
  end

  private

  def generate_order_number
    return if order_number.present?

    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    sequence = organisation.orders.count + 1
    self.order_number = "#{organisation.slug.upcase}-#{timestamp}-#{sequence.to_s.rjust(4, '0')}"
  end
end
