class OrderItem < ApplicationRecord
  include HasExportableColumns

  belongs_to :order
  belongs_to :product
  belongs_to :product_variant, optional: true

  monetize :unit_price, as: :price

  def self.exportable_columns
    [
      { key: :order_number, label: I18n.t("bo.export.columns.order_item.order_number"), default: true,
        value: ->(r) { r.order.order_number } },
      { key: :placed_at, label: I18n.t("bo.export.columns.order_item.placed_at"), default: true,
        value: ->(r) { r.order.placed_at&.strftime("%Y-%m-%d") } },
      { key: :customer_company, label: I18n.t("bo.export.columns.order_item.customer_company"), default: true,
        value: ->(r) { r.order.customer&.company_name } },
      { key: :placed_by_user_name, label: I18n.t("bo.export.columns.order_item.placed_by_user_name"), default: false,
        value: ->(r) { r.order.customer_user&.contact_name } },
      { key: :placed_by_user_email, label: I18n.t("bo.export.columns.order_item.placed_by_user_email"), default: false,
        value: ->(r) { r.order.customer_user&.email } },
      { key: :product_name, label: I18n.t("bo.export.columns.order_item.product_name"), default: true,
        value: ->(r) { r.product&.name } },
      { key: :variant_name, label: I18n.t("bo.export.columns.order_item.variant_name"), default: true,
        value: ->(r) { r.product_variant&.option_values_string.presence } },
      { key: :sku, label: I18n.t("bo.export.columns.order_item.sku"), default: true,
        value: ->(r) { r.product_variant&.sku || r.product&.sku } },
      { key: :quantity, label: I18n.t("bo.export.columns.order_item.quantity"), default: true,
        value: ->(r) { r.quantity } },
      { key: :unit_price, label: I18n.t("bo.export.columns.order_item.unit_price"), default: true,
        value: ->(r) { r.price&.format } },
      { key: :discount, label: I18n.t("bo.export.columns.order_item.discount"), default: true,
        value: ->(r) { r.discount_percentage.to_f > 0 ? "#{(r.discount_percentage * 100).round(1)}%" : nil } },
      { key: :total, label: I18n.t("bo.export.columns.order_item.total"), default: true,
        value: ->(r) { r.total_price.format } },
      { key: :note, label: I18n.t("bo.export.columns.order_item.note"), default: false,
        value: ->(r) { r.note.presence } },
      { key: :order_status, label: I18n.t("bo.export.columns.order_item.order_status"), default: false,
        value: ->(r) { r.order.status&.titleize } },
      { key: :payment_status, label: I18n.t("bo.export.columns.order_item.payment_status"), default: false,
        value: ->(r) { r.order.payment_status&.titleize } }
    ]
  end

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percentage, numericality: { greater_than_or_equal_to: 0,
     less_than_or_equal_to: 1 }, allow_nil: true
  validates :note, length: { maximum: 500 }, allow_blank: true
  validate :variant_belongs_to_product
  validate :variant_is_purchasable, on: :create
  # Only enforced on customer-initiated add/edit (:create, :customer_change),
  # never on system re-pricing/stock-capping (refresh_cart! saves without a
  # context), so an automatic save can't be blocked by a stale minimum.
  validate :meets_minimum_quantity, on: [:create, :customer_change]

  before_validation :set_variant_for_simple_product, on: :create
  before_validation :set_product_from_variant
  before_validation :set_unit_price_from_variant, on: :create
  before_validation :recalculate_discount, if: :should_recalculate_discount?

  # The back office form works in percent (15), the column in fractions (0.15).
  # Assigning it also means a person set this line's discount deliberately, so
  # the automatic calculation leaves it alone — that is the whole point of the
  # field: correcting a bad discount, or granting one. Left blank, it means
  # "work it out for me" and the automatic rules apply as before.
  attr_reader :discount_set_by_hand

  def discount_percent=(value)
    return if value.blank?

    @discount_set_by_hand = true
    self.discount_percentage = value.to_f / 100.0
  end

  def discount_percent
    discount_percentage.present? ? (discount_percentage * 100).round(2) : nil
  end

  def total_price
    subtotal = price * quantity
    discount = subtotal * (discount_percentage || 0)
    return subtotal - discount
  end

  # True when this line's minimum is waived because the variant can't reach it
  # within stock (no backorder) — the customer may then buy up to stock.
  def minimum_waived_by_stock?
    min = product&.enforced_min_quantity
    min.present? && product_variant.present? && product_variant.max_sellable_quantity < min
  end

  def variant_name
    product_variant&.option_values_string.presence || product&.name
  end

  def effective_photo
    product_variant&.effective_photo || (product&.photo_attached? ? product.photo : nil)
  end

  # Classifies the line against current variant stock so the cart/checkout
  # can react per the organisation's policies:
  #   :variant_unpublished — variant is gone or no longer published
  #   :out_of_stock        — variant not purchasable (e.g. tracked stock at 0)
  #   :qty_overflow        — purchasable, but requested qty exceeds stock
  #   :purchasable         — fine to buy at the requested quantity
  def stock_status
    return :variant_unpublished if product_variant.nil? || !product_variant.published?
    return :out_of_stock unless product_variant.purchasable?

    # track_only means the org opted out of stock enforcement (backorder), so
    # an over-stock quantity is not an issue there — only flag it when stock
    # is actually enforced for the variant.
    if product_variant.track_stock? &&
       product_variant.effective_stock_policy != "track_only" &&
       quantity.to_i > product_variant.stock_quantity.to_i
      return :qty_overflow
    end

    :purchasable
  end

  # Re-evaluates unit_price and discount_percentage against the current
  # variant price and active discounts, leaving the new values in memory.
  # Returns a hash of {attribute => [old, new]} for whatever changed (empty
  # when nothing did). The caller decides whether to persist. No-op once the
  # order is placed, so historical orders keep the price they were sold at.
  def refresh_pricing!(cart_context: nil)
    return {} if order&.placed?

    new_price = product_variant&.unit_price_cents || product&.unit_price
    self.unit_price = new_price if new_price.present?

    calculator = DiscountCalculator.new(
      product: product,
      customer: order&.customer,
      quantity: quantity || 1,
      variant: product_variant,
      cart_context: cart_context
    )
    self.discount_percentage = calculator.effective_discount[:percentage] || 0

    changes = {}
    changes[:unit_price] = unit_price_change if unit_price_changed?
    changes[:discount_percentage] = discount_percentage_change if discount_percentage_changed?
    changes
  end

  private

  # The picker chooses a variant; which product it belongs to is not a separate
  # decision. Deriving it keeps a stale or missing product_id from producing an
  # inconsistent line.
  def set_product_from_variant
    return if product_variant.nil?

    self.product_id = product_variant.product_id
  end

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

  def meets_minimum_quantity
    return unless product
    # Combined-scope minimums are checked across all the product's lines
    # (at the cart/checkout level), never per line.
    return if product.min_quantity_combined?

    min = product.enforced_min_quantity
    return unless min
    return if minimum_waived_by_stock?
    return if quantity.to_i >= min

    errors.add(:base, I18n.t("storefront.cart.below_minimum_quantity",
                             product: product.name,
                             minimum: product.minimum_quantity_label))
  end

  def should_recalculate_discount?
    # A discount typed in the back office is a decision, not a starting point.
    return false if discount_set_by_hand

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
