class Order < ApplicationRecord
  include ErpSyncable
  include HasExportableColumns

  STATUSES = %w[in_process processed completed].freeze
  PAYMENT_STATUSES = %w[pending paid failed refunded].freeze
  DELIVERY_METHODS = %w[pickup delivery].freeze
  DISCOUNT_TYPES = %w[percentage fixed].freeze
  PUSH_STATUSES = %w[pending syncing synced failed].freeze
  MAX_PUSH_ATTEMPTS = 5

  monetize :tax_amount_cents, allow_nil: true
  monetize :shipping_amount_cents, allow_nil: true
  monetize :promo_code_discount_amount_cents, allow_nil: true

  # Virtual attribute used by the checkout form: when true, the customer
  # asked to ship to the billing address. Resolved in finalize_checkout!.
  attr_accessor :same_as_billing

  # Virtual attribute set by the checkout form's extra confirmation checkbox,
  # used by validate_checkout_stock! when checkout_stock_policy is "warn".
  attr_accessor :confirmed_stock_warnings

  belongs_to :customer
  belongs_to :customer_user, optional: true
  belongs_to :organisation
  belongs_to :shipping_address, class_name: "Address", optional: true
  belongs_to :billing_address, class_name: "Address", optional: true
  belongs_to :applied_by, class_name: "Member", optional: true
  belongs_to :placed_by, polymorphic: true, optional: true
  belongs_to :sales_rep, class_name: "OrgMember", optional: true
  belongs_to :order_discount, optional: true
  belongs_to :promo_code, optional: true
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items
  has_one :promo_code_redemption, dependent: :destroy

  accepts_nested_attributes_for :order_items, allow_destroy: true, reject_if: :all_blank

  validates :order_number, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :payment_status, inclusion: { in: PAYMENT_STATUSES }
  validates :delivery_method, inclusion: { in: DELIVERY_METHODS }, allow_nil: true
  validates :discount_type, inclusion: { in: DISCOUNT_TYPES }, allow_nil: true
  validates :push_status, inclusion: { in: PUSH_STATUSES }
  validates :discount_value, numericality: { greater_than: 0 }, allow_nil: true
  validate :discount_value_valid_for_type

  before_validation :generate_order_number, on: :create
  before_validation :update_tax, on: :update
  before_save :settle_pending_shipping

  after_commit :enqueue_erp_push, if: :should_enqueue_erp_push?

  # Scopes for cart functionality
  scope :draft, -> { where(placed_at: nil) }
  scope :placed, -> { where.not(placed_at: nil) }
  scope :unreviewed, -> { placed.where(viewed_at: nil) }

  PUSH_RETRY_COOLDOWN = 10.minutes

  # `syncing` is written before the adapter is called, so a process that dies
  # mid-push leaves the order in it forever — nothing retried them, because the
  # retry only ever looked at pending and failed. Two orders sat like that in
  # production from May to September.
  PUSH_STALE_AFTER = 30.minutes

  scope :push_pending, -> { where(push_status: "pending") }
  scope :push_synced, -> { where(push_status: "synced") }
  scope :push_failed, -> { where(push_status: "failed") }
  scope :pushable, -> {
    placed
      .where("push_attempts < ?", MAX_PUSH_ATTEMPTS)
      .where(
        "(orders.push_status IN ('pending', 'failed')" \
        " AND (orders.last_pushed_at IS NULL OR orders.last_pushed_at < :cooldown))" \
        " OR (orders.push_status = 'syncing' AND orders.last_pushed_at < :stale)",
        cooldown: PUSH_RETRY_COOLDOWN.ago,
        stale: PUSH_STALE_AFTER.ago
      )
  }

  def self.exportable_columns
    [
      { key: :order_number, label: I18n.t("bo.export.columns.order.order_number"), default: true,
        value: ->(r) { r.order_number } },
      { key: :customer_company, label: I18n.t("bo.export.columns.order.customer_company"), default: true,
        value: ->(r) { r.customer&.company_name } },
      { key: :customer_contact, label: I18n.t("bo.export.columns.order.customer_contact"), default: true,
        value: ->(r) { r.customer&.contact_name } },
      { key: :customer_email, label: I18n.t("bo.export.columns.order.customer_email"), default: false,
        value: ->(r) { r.customer&.email } },
      { key: :placed_by_user_name, label: I18n.t("bo.export.columns.order.placed_by_user_name"), default: false,
        value: ->(r) { r.customer_user&.contact_name } },
      { key: :placed_by_user_email, label: I18n.t("bo.export.columns.order.placed_by_user_email"), default: false,
        value: ->(r) { r.customer_user&.email } },
      { key: :status, label: I18n.t("bo.export.columns.order.status"), default: true,
        value: ->(r) { r.status&.titleize } },
      { key: :payment_status, label: I18n.t("bo.export.columns.order.payment_status"), default: true,
        value: ->(r) { r.payment_status&.titleize } },
      { key: :placed_at, label: I18n.t("bo.export.columns.order.placed_at"), default: true,
        value: ->(r) { r.placed_at&.strftime("%Y-%m-%d %H:%M") } },
      { key: :receive_on, label: I18n.t("bo.export.columns.order.receive_on"), default: false,
        value: ->(r) { r.receive_on&.strftime("%Y-%m-%d") } },
      { key: :delivery_method, label: I18n.t("bo.export.columns.order.delivery_method"), default: false,
        value: ->(r) { r.delivery_method&.titleize } },
      { key: :item_count, label: I18n.t("bo.export.columns.order.item_count"), default: true,
        value: ->(r) { r.order_items.sum(:quantity) } },
      { key: :total_amount, label: I18n.t("bo.export.columns.order.total_amount"), default: true,
        value: ->(r) { r.total_amount.format } },
      { key: :grand_total, label: I18n.t("bo.export.columns.order.grand_total"), default: true,
        value: ->(r) { r.grand_total.format } },
      { key: :notes, label: I18n.t("bo.export.columns.order.notes"), default: false,
        value: ->(r) { r.notes } }
    ]
  end

  def draft?
    placed_at.nil?
  end

  def placed?
    placed_at.present?
  end

  def mark_as_reviewed!
    update_column(:viewed_at, Time.current) if viewed_at.nil?
  end

  def item_count
    order_items.sum(:quantity)
  end

  def line_item_count
    order_items.size
  end

  def place!
    update!(placed_at: Time.current)
    # The customer ended up taking these products — close any open demand they
    # satisfy (decision 4: a falta fecha-se sozinha).
    UnmetDemandRecorder.resolve_for_placed_order(self)
  end

  def push_synced?
    push_status == "synced"
  end

  def push_failed?
    push_status == "failed"
  end

  def push_pending?
    push_status == "pending"
  end

  def push_exhausted?
    push_attempts >= MAX_PUSH_ATTEMPTS
  end

  # A push that started but never finished: the process was killed between
  # marking `syncing` and hearing back from the ERP.
  def push_stale?
    push_status == "syncing" && last_pushed_at.present? && last_pushed_at < PUSH_STALE_AFTER.ago
  end

  # Nothing will move this order on its own — it has run out of attempts, or it
  # is stuck part-way. Worth offering a person the chance to send it again.
  def push_stuck?
    placed? && !push_synced? && (push_failed? || push_exhausted? || push_stale?)
  end

  # Re-evaluates every line item against current data — re-pricing it and
  # reacting to stock changes per the organisation's cart policies — and
  # persists what moved. Returns a struct describing every change so callers
  # (cart/checkout) can surface it. No-op once the order is placed.
  #
  # Stock reactions:
  #   cart_stock_policy 'remove'    → drop items that went unpurchasable
  #   cart_qty_overflow_policy 'cap' → reduce qty to the available stock
  #   otherwise the issue is recorded for the view to warn about.
  def refresh_cart!
    changes = blank_cart_changes
    return changes if placed?

    # Built once so each line can evaluate "summed" discount conditions against
    # the whole cart (a product's variants, or a category total).
    cart_context = CartDiscountContext.new(order_items.includes(:product_variant, product: :categories).to_a)

    order_items.to_a.each do |item|
      status = item.stock_status

      if status.in?(%i[out_of_stock variant_unpublished]) && organisation.cart_stock_policy == "remove"
        changes[:removed] << cart_item_label(item)
        record_unmet_demand(item, requested: item.quantity, kept: 0, reason: :removed)
        item.destroy!
        next
      end

      item_changes = item.refresh_pricing!(cart_context: cart_context)
      if item_changes.any?
        item.save!
        changes[:price_changed] << item.id if item_changes.key?(:unit_price)
        changes[:discount_changed] << item.id if item_changes.key?(:discount_percentage)
      end

      case status
      when :out_of_stock, :variant_unpublished
        changes[:out_of_stock] << cart_item_label(item)
      when :qty_overflow
        available = item.product_variant.stock_quantity.to_i
        if organisation.cart_qty_overflow_policy == "cap" && available >= 1
          # Record before the update — item.quantity still holds the original
          # requested amount here; the cap below overwrites it.
          record_unmet_demand(item, requested: item.quantity, kept: available, reason: :capped)
          item.update!(quantity: available)
          changes[:capped] << cart_item_label(item).merge(to: available)
        else
          changes[:qty_overflow] << cart_item_label(item).merge(available: available)
        end
      end
    end

    # Under the "confirm" price-change policy we persist that a change is
    # pending, so the checkout can require an explicit acknowledgement even
    # if the customer first saw the change on the cart page.
    if (changes[:price_changed].any? || changes[:discount_changed].any?) &&
       organisation.cart_price_change_policy == "confirm"
      update_column(:pricing_changed_at, Time.current)
    end

    changes
  end

  def pricing_change_pending?
    pricing_changed_at.present?
  end

  def acknowledge_pricing_change!
    update_column(:pricing_changed_at, nil) if pricing_changed_at.present?
  end

  # Line items that aren't cleanly purchasable at the requested quantity.
  def stock_issue_items
    order_items.reject { |item| item.stock_status == :purchasable }
  end

  def stock_issues?
    stock_issue_items.any?
  end

  # Enforces the organisation's checkout_stock_policy when finalising:
  #   allow → backorder, no-op
  #   block → refuse to place if any item has a stock issue
  #   warn  → refuse unless the customer ticked the confirmation checkbox
  # Runs after refresh_cart!, so items already removed/capped by the cart
  # policies are no longer counted here.
  def validate_checkout_stock!
    policy = organisation.checkout_stock_policy
    return if policy == "allow" || stock_issue_items.empty?

    if policy == "block"
      errors.add(:base, I18n.t("storefront.checkouts.errors.stock_blocked"))
      raise ActiveRecord::RecordInvalid, self
    elsif policy == "warn" && !ActiveModel::Type::Boolean.new.cast(confirmed_stock_warnings)
      errors.add(:base, I18n.t("storefront.checkouts.errors.stock_unconfirmed"))
      raise ActiveRecord::RecordInvalid, self
    end
  end

  # Under the "confirm" policy, refuse to place until the customer has
  # acknowledged a pending price/discount change (cleared via the modal).
  def validate_pricing_acknowledged!
    return unless organisation.cart_price_change_policy == "confirm"
    return unless pricing_change_pending?

    errors.add(:base, I18n.t("storefront.checkouts.errors.pricing_unconfirmed"))
    raise ActiveRecord::RecordInvalid, self
  end

  # Combined-scope products whose minimum isn't met by the SUM of their lines.
  # Returns [{ product:, required:, current:, label:, shortfall: }]. Used for
  # the cart warning and the checkout gate.
  def combined_min_quantity_shortfalls
    order_items.reload.group_by(&:product).filter_map do |product, items|
      next unless product&.min_quantity_combined?

      min = product.enforced_min_quantity
      next unless min
      # Waive when the minimum can't be reached within stock (no backorder).
      next unless product.combined_min_reachable?

      current = items.sum { |i| i.quantity.to_i }
      next if current >= min

      { product: product, required: min, current: current,
        label: product.minimum_quantity_label, shortfall: min - current }
    end
  end

  # Hard gate: refuse to place an order below the product minimum — per line for
  # per_variant products, or by the combined total for combined products.
  # Catches legacy/grid-built carts that never passed the earlier checks.
  def validate_minimum_quantities!
    messages = []

    order_items.reload.each do |item|
      product = item.product
      next unless product && !product.min_quantity_combined?

      min = product.enforced_min_quantity
      next unless min && item.quantity.to_i < min
      # Waive when stock can't reach the minimum (no backorder).
      next if item.minimum_waived_by_stock?

      messages << I18n.t("storefront.cart.below_minimum_quantity",
                         product: product.name, minimum: product.minimum_quantity_label)
    end

    combined_min_quantity_shortfalls.each do |s|
      messages << I18n.t("storefront.cart.below_minimum_combined",
                         product: s[:product].name, minimum: s[:label], current: s[:current])
    end

    return if messages.empty?

    messages.each { |msg| errors.add(:base, msg) }
    raise ActiveRecord::RecordInvalid, self
  end

  def finalize_checkout!(same_as_billing: false)
    self.shipping_address = billing_address if same_as_billing && billing_address.present?
    refresh_cart!
    validate_checkout_stock!
    validate_minimum_quantities!
    validate_pricing_acknowledged!
    self.tax_amount = calculated_tax
    self.shipping_pending = deferred_shipping?
    self.shipping_amount = shipping_pending ? nil : calculated_shipping
    snapshot_auto_discount!
    snapshot_promo_code!

    if terms_accepted_at.blank?
      errors.add(:base, "You must accept the terms and conditions")
      raise ActiveRecord::RecordInvalid, self
    end

    validate_receive_on!
    place!
  end

  # Seeded with a zero Money: summing an empty set gives the integer 0, and
  # every caller here goes on to ask it for `.cents` or add Money to it. An
  # order with no lines — one emptied before its replacement line is added —
  # raised NoMethodError on save.
  def total_amount
    order_items.sum(Money.new(0, organisation&.currency || "EUR"), &:total_price)
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
    if placed? && has_auto_discount_snapshot?
      Money.new(auto_discount_amount_cents, organisation.currency)
    elsif best_order_discount.present?
      best_order_discount.calculate_discount(total_amount)
    else
      Money.new(0, organisation.currency)
    end
  end

  def has_auto_discount_snapshot?
    auto_discount_amount_cents.present?
  end

  def auto_discount_display
    return nil unless has_auto_discount_snapshot?

    if auto_discount_type == 'percentage'
      "#{(auto_discount_value * 100).round(0)}%"
    else
      "#{organisation.currency_symbol}#{auto_discount_value}"
    end
  end

  # Total with automatic order tier discount applied (before manual discounts)
  def total_with_auto_discount
    result = total_amount - auto_order_discount_amount
    [result, Money.new(0, organisation.currency)].max
  end

  def pickup?
    delivery_method == "pickup"
  end

  def delivery?
    delivery_method == "delivery"
  end

  # Calculate shipping based on delivery method and organisation's shipping cost.
  # Under the "calculated on dispatch" mode there is no amount to charge yet, so
  # this is zero and the order carries shipping_pending? instead — the caller is
  # expected to show "to be calculated" rather than a misleading free shipping.
  def calculated_shipping
    return Money.new(0, organisation.currency) if pickup?
    return Money.new(0, organisation.currency) if qualifies_for_free_shipping?
    return Money.new(0, organisation.currency) if deferred_shipping?
    organisation.shipping_cost
  end

  # Does the organisation's current setting defer this order's shipping cost to
  # dispatch time? Pickup and free-shipping orders are settled at checkout even
  # in that mode — there is nothing left to calculate.
  def deferred_shipping?
    return false unless organisation.shipping_calculated_on_dispatch?
    return false if pickup?
    return false if qualifies_for_free_shipping?
    true
  end

  # Whether the shipping cost is still to be determined. Placed orders answer
  # from the snapshot taken at checkout; a cart has no snapshot yet, so it
  # answers from the organisation's current setting.
  def shipping_pending?
    draft? ? deferred_shipping? : shipping_pending
  end

  # The shipping actually owed on this order. Zero while it is still pending —
  # never fall back to calculated_shipping in that case, or an order placed
  # under "calculated on dispatch" would silently grow a flat rate the day the
  # organisation switches back to fixed shipping.
  def effective_shipping
    return Money.new(0, organisation.currency) if shipping_pending?
    shipping_amount || calculated_shipping
  end

  def qualifies_for_free_shipping?
    return false unless organisation.free_shipping_enabled?
    total_with_auto_discount >= organisation.free_shipping_threshold
  end

  def free_shipping_amount_remaining
    return nil unless organisation.free_shipping_enabled?
    return Money.new(0, organisation.currency) if qualifies_for_free_shipping?
    organisation.free_shipping_threshold - total_with_auto_discount
  end

  # Order discount methods
  def has_order_discount?
    discount_type.present? && discount_value.present?
  end

  def order_discount_amount
    return Money.new(0, organisation.currency) unless has_order_discount?

    case discount_type
    when 'percentage'
      # Compound: the manual discount applies last, on the total already reduced
      # by the auto tier and the promo code — not on the gross total.
      base = [total_with_auto_discount - promo_code_discount, Money.new(0, organisation.currency)].max
      base * discount_value
    when 'fixed'
      Money.new((discount_value * 100).to_i, organisation.currency)
    else
      Money.new(0, organisation.currency)
    end
  end

  # Sum of line totals BEFORE any discount (base price × quantity) — the
  # reference for the organisation's maximum-discount cap.
  def gross_subtotal
    order_items.sum { |i| i.price * i.quantity }
  end

  def subtotal_after_discount
    cap_subtotal(raw_subtotal_after_discount)
  end

  # True when the org's maximum-discount cap actually reduced the total discount.
  def discount_capped?
    organisation.max_discount_enabled? && raw_subtotal_after_discount < max_discount_floor
  end

  def promo_code_discount
    if placed? && promo_code_discount_amount_cents.present? && promo_code_discount_amount_cents > 0
      Money.new(promo_code_discount_amount_cents, organisation.currency)
    elsif promo_code.present? && draft?
      promo_code.calculate_discount(total_with_auto_discount)
    else
      Money.new(0, organisation.currency)
    end
  end

  def has_promo_code?
    promo_code.present?
  end

  # True when the order already carries another order-level discount (an
  # applicable auto tier or a manual discount). Used to block a non-stackable
  # promo code. Line-level discounts (customer/product) are the customer's base
  # pricing and don't count here.
  def has_other_order_level_discount?
    best_order_discount.present? || has_order_discount?
  end

  def order_discount_display
    return nil unless has_order_discount?

    if discount_type == 'percentage'
      "#{(discount_value * 100).round(0)}%"
    else
      "#{organisation.currency_symbol}#{discount_value}"
    end
  end

  # Grand total including tax and shipping
  def grand_total
    subtotal_after_discount + (tax_amount || calculated_tax) + effective_shipping
  end

  # Calculate tax based on subtotal after discount
  def calculated_tax
    subtotal_after_discount * organisation.tax_rate
  end

  def validate_receive_on!
    return if receive_on.blank?

    unless organisation.valid_delivery_day?(receive_on)
      errors.add(:receive_on, :invalid_delivery_day)
      raise ActiveRecord::RecordInvalid, self
    end

    if receive_on < organisation.earliest_delivery_date
      errors.add(:receive_on, :too_early)
      raise ActiveRecord::RecordInvalid, self
    end
  end

  private

  # Pricing the shipping is what closes the "to be calculated" state: the moment
  # an amount lands on the order, it is no longer pending. Reads the column
  # directly — shipping_pending? falls back to the live rule for carts, and a
  # cart must stay pending regardless of what it currently holds.
  def settle_pending_shipping
    return unless self[:shipping_pending]
    return unless shipping_amount_cents.present?

    self.shipping_pending = false
  end

  # Order-level discounts compound, each on the already-discounted running
  # total: gross -> auto tier -> promo code -> manual discount.
  def raw_subtotal_after_discount
    result = total_with_auto_discount - order_discount_amount - promo_code_discount
    [result, Money.new(0, organisation.currency)].max
  end

  def max_discount_floor
    gross_subtotal * (1 - organisation.max_discount_percentage)
  end

  def cap_subtotal(subtotal)
    return subtotal unless organisation.max_discount_enabled?
    [subtotal, max_discount_floor].max
  end

  def blank_cart_changes
    { price_changed: [], discount_changed: [], removed: [], capped: [], out_of_stock: [], qty_overflow: [] }
  end

  def cart_item_label(item)
    { id: item.id, name: item.product&.name, variant: item.variant_name }
  end

  def record_unmet_demand(item, requested:, kept:, reason:)
    UnmetDemandRecorder.record(
      order:           self,
      product:         item.product,
      product_variant: item.product_variant,
      requested:       requested,
      kept:            kept,
      reason:          reason
    )
  end

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

  # Fires an async push to the ERP when an order transitions into `placed`
  # state. Idempotent — the service no-ops if the order is already synced
  # or the org has ERP disabled.
  def should_enqueue_erp_push?
    saved_change_to_placed_at? && placed_at.present? && push_pending?
  end

  def enqueue_erp_push
    OrderPushJob.perform_later(id)
  end

  def snapshot_auto_discount!
    if (discount = best_order_discount)
      self.order_discount = discount
      self.auto_discount_type = discount.discount_type
      self.auto_discount_value = discount.discount_value
      self.auto_discount_amount_cents = discount.calculate_discount(total_amount).cents
    end
  end

  def snapshot_promo_code!
    return unless promo_code.present?

    result = promo_code.redeemable_by?(customer, self)
    if result != :ok
      self.promo_code = nil
      self.promo_code_discount_amount_cents = 0
      return
    end

    discount_amount = promo_code.calculate_discount(total_with_auto_discount)
    self.promo_code_discount_amount_cents = discount_amount.cents

    PromoCodeRedemption.create!(
      promo_code: promo_code,
      customer: customer,
      order: self,
      discount_amount_cents: discount_amount.cents
    )

    promo_code.class.where(id: promo_code.id)
      .update_all("usage_count = usage_count + 1")
  end
end
