# Append-only trail of stock transitions.
#
# `product_variants.stock_quantity` is overwritten in place by the ERP sync, so
# the current value answers "is it out of stock now?" but never "when did it go
# out of stock?". Automations (weekly digests, restock notifications) need the
# latter, hence this log.
#
# Rows are written by StockRulesService — the single funnel every stock change
# already passes through — and never updated or deleted.
class StockEvent < ApplicationRecord
  OUT_OF_STOCK  = "out_of_stock".freeze
  BACK_IN_STOCK = "back_in_stock".freeze
  LOW_STOCK     = "low_stock".freeze
  KINDS = [ OUT_OF_STOCK, BACK_IN_STOCK, LOW_STOCK ].freeze

  belongs_to :organisation
  belongs_to :product_variant

  has_one :product, through: :product_variant

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :occurred_at, presence: true

  scope :out_of_stock,  -> { where(kind: OUT_OF_STOCK) }
  scope :back_in_stock, -> { where(kind: BACK_IN_STOCK) }
  scope :low_stock,     -> { where(kind: LOW_STOCK) }
  scope :in_period,     ->(period) { where(occurred_at: period) }
  scope :recent,        -> { order(occurred_at: :desc) }

  # The placeholder base variant of a variable product isn't a sellable unit.
  # The log stays faithful and records it; reports filter it out here.
  scope :real_units, -> {
    joins(product_variant: :product)
      .where("NOT (product_variants.is_default AND products.has_variants)")
  }

  # Derives the kind of a transition, or nil when the move doesn't cross any
  # threshold worth logging (e.g. 12 -> 9 with a threshold of 5).
  def self.kind_for(from:, to:, low_stock_threshold:)
    from = from.to_i
    to   = to.to_i

    return OUT_OF_STOCK  if from > 0 && to <= 0
    return BACK_IN_STOCK if from <= 0 && to > 0

    threshold = low_stock_threshold.to_i
    return LOW_STOCK if threshold > 0 && from > threshold && to <= threshold && to > 0

    nil
  end
end
