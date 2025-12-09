class Order < ApplicationRecord
  STATUSES = %w[in_process processed completed].freeze
  PAYMENT_STATUSES = %w[pending paid failed refunded].freeze
  DELIVERY_METHODS = %w[pickup delivery].freeze

  monetize :tax_amount_cents, allow_nil: true
  monetize :shipping_amount_cents, allow_nil: true

  belongs_to :customer
  belongs_to :organisation
  belongs_to :shipping_address, class_name: "Address", optional: true
  belongs_to :billing_address, class_name: "Address", optional: true
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  accepts_nested_attributes_for :order_items, allow_destroy: true, reject_if: :all_blank

  validates :order_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
  validates :delivery_method, inclusion: { in: DELIVERY_METHODS }, allow_nil: true

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

  def pickup?
    delivery_method == "pickup"
  end

  def delivery?
    delivery_method == "delivery"
  end

  # Calculate tax based on organisation's tax rate
  def calculated_tax
    total_amount * organisation.tax_rate
  end

  # Calculate shipping based on delivery method and organisation's shipping cost
  def calculated_shipping
    pickup? ? Money.new(0, 'EUR') : organisation.shipping_cost
  end

  # Grand total including tax and shipping
  def grand_total
    total_amount + (tax_amount || calculated_tax) + (shipping_amount || calculated_shipping)
  end

  private

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
