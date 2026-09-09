# Tracks B2B demand a customer wanted but couldn't take, because a cart stock
# policy cut it on cart/checkout entry (a line removed for being out of stock,
# or a quantity capped to available stock — see Order#refresh_cart!).
#
# Keyed by the LOGIN (customer_user) that hit the shortfall, not just the
# empresa: each login has its own cart, so actions target that login's cart and
# the BO knows who to contact. One OPEN row per login + product + variant
# (decision 1a): repeated cart refreshes update the same row. Every cut also
# appends an immutable UnmetDemandOccurrence so the history is never lost.
class UnmetDemand < ApplicationRecord
  REASONS     = %w[capped removed].freeze
  STATUSES    = %w[open resolved dismissed].freeze
  RESOLUTIONS = %w[customer_self_served draft_generated substituted dismissed].freeze

  belongs_to :organisation
  belongs_to :customer
  belongs_to :customer_user
  belongs_to :product
  belongs_to :product_variant, optional: true
  belongs_to :order, optional: true
  belongs_to :substitute_product, class_name: "Product", optional: true
  belongs_to :resolved_by_member, class_name: "Member", optional: true

  has_many :occurrences, class_name: "UnmetDemandOccurrence", dependent: :nullify

  validates :requested_quantity, numericality: { greater_than: 0 }
  validates :fulfilled_quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :reason,  inclusion: { in: REASONS }
  validates :status,  inclusion: { in: STATUSES }
  validates :resolution, inclusion: { in: RESOLUTIONS }, allow_nil: true

  scope :open,      -> { where(status: "open") }
  scope :resolved,  -> { where(status: "resolved") }
  scope :dismissed, -> { where(status: "dismissed") }

  def open?
    status == "open"
  end

  # The headline BO number: how much of what they wanted they still haven't
  # received via a placed order.
  def shortfall
    [requested_quantity.to_i - fulfilled_quantity.to_i, 0].max
  end

  # Quantity of this product/variant currently sitting in the login's open
  # draft cart (not yet placed). Shown alongside "taken" so the BO sees the
  # capped amount is pending, not lost.
  def quantity_in_cart
    cart = customer_user.orders.draft.find_by(organisation_id: organisation_id)
    return 0 unless cart

    cart.order_items
        .where(product_id: product_id)
        .where(product_variant_id: product_variant_id)
        .sum(:quantity)
  end

  # Can the shortfall be met from current stock right now?
  def satisfiable_from_stock?
    return true if product_variant.nil?
    product_variant.sells_without_stock? || product_variant.stock_quantity.to_i >= shortfall
  end

  def sku
    product_variant&.sku.presence
  end

  # Current stock of the variant: nil if the variant is gone, Infinity if it
  # backorders/doesn't track, else the on-hand quantity.
  def current_stock
    return nil if product_variant.nil?
    return Float::INFINITY if product_variant.sells_without_stock?
    product_variant.stock_quantity.to_i
  end

  # Full occurrence history for this login + product + variant, spanning every
  # episode (including ones from prior, already-closed aggregate rows) — so the
  # BO never loses sight that an article was ever short.
  def occurrence_history
    UnmetDemandOccurrence
      .where(customer_user_id: customer_user_id, product_id: product_id, product_variant_id: product_variant_id)
      .recent_first
  end

  # Customer placed an order containing this product — credit the quantity and
  # close the demand once fully met. Called from UnmetDemandRecorder on place!.
  def register_fulfilment!(quantity)
    return unless open?

    self.fulfilled_quantity = fulfilled_quantity.to_i + quantity.to_i
    if fulfilled_quantity >= requested_quantity
      update!(status: "resolved", resolution: "customer_self_served", resolved_at: Time.current)
    else
      save!
    end
  end

  # BO action: add the outstanding shortfall (of this variant, or a chosen
  # substitute VARIANT) to the login's own draft cart, then resolve and link it.
  def satisfy!(member:, substitute_variant: nil, quantity: nil)
    raise ActiveRecord::RecordInvalid, self unless open?

    add_variant = substitute_variant || product_variant
    add_product = substitute_variant ? substitute_variant.product : product
    qty = (quantity.presence || shortfall).to_i
    raise ActiveRecord::RecordInvalid, self if qty <= 0

    cart = login_draft_cart!

    transaction do
      cart.order_items.create!(
        product_id:         add_product.id,
        product_variant_id: add_variant&.id,
        quantity:           qty
      )
      update!(
        status:                "resolved",
        resolution:            substitute_variant ? "substituted" : "draft_generated",
        substitute_product:    substitute_variant&.product,
        order:                 cart,
        resolved_by_member_id: member&.id,
        resolved_at:           Time.current
      )
    end

    cart
  end

  def dismiss!(member:)
    return unless open?

    update!(
      status:                "dismissed",
      resolution:            "dismissed",
      resolved_by_member_id: member&.id,
      resolved_at:           Time.current
    )
  end

  private

  # The draft cart of the specific login that hit the shortfall.
  def login_draft_cart!
    customer_user.current_cart(organisation)
  end
end
