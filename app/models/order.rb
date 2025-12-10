class Order < ApplicationRecord
  STATUSES = %w[in_process processed completed].freeze
  PAYMENT_STATUSES = %w[pending paid failed refunded].freeze
  DELIVERY_METHODS = %w[pickup delivery].freeze
  DISCOUNT_TYPES = %w[percentage fixed].freeze

  monetize :tax_amount_cents, allow_nil: true
  monetize :shipping_amount_cents, allow_nil: true

  belongs_to :customer
  belongs_to :organisation
  belongs_to :shipping_address, class_name: "Address", optional: true
  belongs_to :billing_address, class_name: "Address", optional: true
  belongs_to :applied_by, class_name: "Member", optional: true
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  accepts_nested_attributes_for :order_items, allow_destroy: true, reject_if: :all_blank

  validates :order_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
  validates :delivery_method, inclusion: { in: DELIVERY_METHODS }, allow_nil: true
  validates :discount_type, inclusion: { in: DISCOUNT_TYPES }, allow_nil: true
  validates :discount_value, numericality: { greater_than: 0 }, allow_nil: true
  validate :discount_value_valid_for_type

  before_validation :generate_order_number, on: :create
  before_validation :update_tax, on: :update

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

  def finalize_checkout!(same_as_shipping: false)
    self.billing_address = shipping_address if same_as_shipping && shipping_address.present?
    self.tax_amount = calculated_tax
    self.shipping_amount = calculated_shipping
    place!
  end

  def total_amount
    order_items.sum(&:total_price)
  end

  # Find the best applicable order tier discount
  def best_order_discount
    @best_order_discount ||= organisation.order_discounts
      .active
      .where("min_order_amount_cents <= ?", total_amount.cents)
      .order(min_order_amount_cents: :desc)
      .first
  end

  # Calculate the automatic order tier discount amount
  def auto_order_discount_amount
    return Money.new(0, 'EUR') unless best_order_discount.present?

    best_order_discount.calculate_discount(total_amount)
  end

  # Total with automatic order tier discount applied (before manual discounts)
  def total_with_auto_discount
    result = total_amount - auto_order_discount_amount
    [result, Money.new(0, 'EUR')].max
  end

  def pickup?
    delivery_method == "pickup"
  end

  def delivery?
    delivery_method == "delivery"
  end

  # Calculate shipping based on delivery method and organisation's shipping cost
  def calculated_shipping
    pickup? ? Money.new(0, 'EUR') : organisation.shipping_cost
  end

  # Order discount methods
  def has_order_discount?
    discount_type.present? && discount_value.present?
  end

  def order_discount_amount
    return Money.new(0, 'EUR') unless has_order_discount?

    case discount_type
    when 'percentage'
      total_amount * discount_value
    when 'fixed'
      Money.new((discount_value * 100).to_i, 'EUR')
    else
      Money.new(0, 'EUR')
    end
  end

  def subtotal_after_discount
    # Apply both auto order tier discount and manual order discount
    result = total_with_auto_discount - order_discount_amount
    [result, Money.new(0, 'EUR')].max
  end

  def order_discount_display
    return nil unless has_order_discount?

    if discount_type == 'percentage'
      "#{(discount_value * 100).round(0)}%"
    else
      "€#{discount_value}"
    end
  end

  # Grand total including tax and shipping
  def grand_total
    subtotal_after_discount + (tax_amount || calculated_tax) + (shipping_amount || calculated_shipping)
  end

  # Calculate tax based on subtotal after discount
  def calculated_tax
    subtotal_after_discount * organisation.tax_rate
  end

  private

  def discount_value_valid_for_type
    return unless discount_type.present? && discount_value.present?

    if discount_type == 'percentage' && discount_value > 1
      errors.add(:discount_value, "must be between 0 and 1 for percentage discounts")
    end
  end

  def generate_order_number
    return if order_number.present?

    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    sequence = organisation.orders.count + 1
    self.order_number = "#{organisation.slug.upcase}-#{timestamp}-#{sequence.to_s.rjust(4, '0')}"
  end

  def update_tax
    self.tax_amount = calculated_tax
  end
end
