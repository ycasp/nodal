# Append-only audit line: one per time a cart stock policy cut a customer's
# line. Never updated. Grouped by login + product + variant for the BO history
# view, independent of which (open/closed) UnmetDemand aggregate was live then.
class UnmetDemandOccurrence < ApplicationRecord
  REASONS = %w[capped removed].freeze

  belongs_to :unmet_demand, optional: true
  belongs_to :organisation
  belongs_to :customer
  belongs_to :customer_user
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :requested_quantity, numericality: { greater_than: 0 }
  validates :kept_quantity, numericality: { greater_than_or_equal_to: 0 }
  validates :reason, inclusion: { in: REASONS }

  scope :recent_first, -> { order(occurred_at: :desc) }

  # What the customer didn't get at this single occurrence.
  def short_quantity
    [requested_quantity.to_i - kept_quantity.to_i, 0].max
  end
end
