class CustomerDiscount < ApplicationRecord
  DISCOUNT_TYPES = %w[percentage fixed].freeze

  belongs_to :customer
  belongs_to :organisation

  validates :discount_type, presence: true, inclusion: { in: DISCOUNT_TYPES }
  validates :discount_value, presence: true, numericality: { greater_than: 0 }

  validate :discount_value_valid_for_type
  validate :valid_until_after_valid_from
  validate :no_overlapping_discounts

  scope :active, -> {
    where(active: true)
      .where("(valid_from IS NULL OR valid_from <= ?) AND (valid_until IS NULL OR valid_until >= ?)",
             Date.current, Date.current)
  }

  def percentage?
    discount_type == 'percentage'
  end

  def fixed?
    discount_type == 'fixed'
  end

  def perpetual?
    valid_from.nil? && valid_until.nil?
  end

  def value_display
    if percentage?
      "#{(discount_value * 100).round(0)}%"
    else
      discount_value
    end
  end

  def valid_period_display
    if perpetual?
      "No expiry"
    elsif valid_from.present? && valid_until.present?
      "#{valid_from.strftime('%Y-%m-%d')} to #{valid_until.strftime('%Y-%m-%d')}"
    elsif valid_from.present?
      "From #{valid_from.strftime('%Y-%m-%d')}"
    elsif valid_until.present?
      "Until #{valid_until.strftime('%Y-%m-%d')}"
    end
  end

  private

  def discount_value_valid_for_type
    return unless discount_value.present? && discount_type.present?

    if percentage? && discount_value > 1
      errors.add(:discount_value, "must be between 0 and 1 for percentage discounts (e.g., 0.15 for 15%)")
    end
  end

  def valid_until_after_valid_from
    return if valid_from.blank? || valid_until.blank?

    if valid_until < valid_from
      errors.add(:valid_until, "must be after valid from date")
    end
  end

  def no_overlapping_discounts
    return if customer_id.blank?

    overlapping = CustomerDiscount
      .where(customer_id: customer_id)
      .where.not(id: id)

    if valid_from.present? && valid_until.present?
      overlapping = overlapping.where(
        "(valid_from IS NULL OR valid_from <= ?) AND (valid_until IS NULL OR valid_until >= ?)",
        valid_until, valid_from
      )
    elsif perpetual?
      # Perpetual discount - check if any other discount exists
      overlapping = overlapping.all
    else
      # One date is nil
      if valid_from.nil?
        overlapping = overlapping.where("valid_until IS NULL OR valid_until >= ?", Date.current)
      else
        overlapping = overlapping.where("valid_from IS NULL OR valid_from <= ?", valid_until || Date.current + 100.years)
      end
    end

    errors.add(:base, "overlaps with an existing discount for this customer") if overlapping.exists?
  end
end
