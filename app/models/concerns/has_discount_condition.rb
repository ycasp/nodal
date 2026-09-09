module HasDiscountCondition
  extend ActiveSupport::Concern

  CONDITION_TYPES = %w[none quantity amount].freeze
  CONDITION_SCOPES = %w[per_line summed].freeze

  included do
    monetize :min_amount_cents, as: :min_amount, allow_nil: true
    validates :condition_type, inclusion: { in: CONDITION_TYPES }
    validates :condition_scope, inclusion: { in: CONDITION_SCOPES }
    validates :min_amount_cents, numericality: { greater_than: 0 }, if: :amount_condition?
    validates :min_quantity, numericality: { greater_than: 0, only_integer: true }, if: :quantity_condition?
  end

  def quantity_condition?
    condition_type == "quantity"
  end

  def amount_condition?
    condition_type == "amount"
  end

  def no_condition?
    condition_type == "none"
  end

  # Summed: the threshold is checked across the discount's whole target (a
  # product's variants, or all products in a category) rather than per line.
  def summed_condition?
    condition_scope == "summed" && !no_condition?
  end

  # Does the line meet this discount's condition?
  #   quantity — line quantity >= min_quantity
  #   amount   — line value (base price × quantity) >= min_amount
  #   none     — always
  def condition_met?(quantity:, line_amount_cents:)
    case condition_type
    when "amount"   then line_amount_cents.to_i >= min_amount_cents.to_i
    when "quantity" then quantity.to_i >= min_quantity.to_i
    else true
    end
  end

  # Structured requirement for the storefront "unlock" nudge, or nil.
  def condition_requirement
    base = { scope: condition_scope.to_sym, target: (category_id ? :category : :product) }
    case condition_type
    when "amount"   then base.merge(type: :amount, amount: min_amount)
    when "quantity" then base.merge(type: :quantity, quantity: min_quantity)
    end
  end

  # Short human label for BO lists, e.g. "5" (qty), "€50.00", or "—".
  def condition_display
    case condition_type
    when "amount"   then min_amount&.format
    when "quantity" then min_quantity.to_s
    else "—"
    end
  end
end
