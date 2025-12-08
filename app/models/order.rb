class Order < ApplicationRecord
  STATUSES = %w[in_process processed completed].freeze
  PAYMENT_STATUSES = %w[pending paid failed refunded].freeze

  belongs_to :customer
  belongs_to :organisation
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  accepts_nested_attributes_for :order_items, allow_destroy: true, reject_if: :all_blank

  validates :order_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }

  before_validation :generate_order_number, on: :create

  # Scopes for cart functionality
  scope :draft, -> { where(placed_at: nil) }
  scope :placed, -> { where.not(placed_at: nil) }

  def draft?
    placed_at.nil?
  end

  def placed?
    placed_at.present?
  end

  def item_count
    order_items.sum(:quantity)
  end

  def place!
    update!(placed_at: Time.current)
  end

  def total_amount
    order_items.sum(&:total_price)
  end

  private

  def generate_order_number
    return if order_number.present?

    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    sequence = organisation.orders.count + 1
    self.order_number = "#{organisation.slug.upcase}-#{timestamp}-#{sequence.to_s.rjust(4, '0')}"
  end
end
