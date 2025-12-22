class CustomerProductDiscount < ApplicationRecord
  DISCOUNT_TYPES = %w[percentage fixed].freeze

  belongs_to :customer
  belongs_to :product
  belongs_to :organisation

  validates :discount_type, presence: true, inclusion: { in: DISCOUNT_TYPES }
  validates :discount_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  validate :valid_until_after_valid_from
  validate :dates_not_in_past, on: :create
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

  def percentage_display
    (discount_percentage * 100).round(0)
  end

  def value_display
    if percentage?
      "#{percentage_display}%"
    else
      discount_percentage
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

  def valid_until_after_valid_from
    return if valid_from.blank? || valid_until.blank?

    if valid_until < valid_from
      errors.add(:valid_until, "must be after valid from date")
    end
  end

  def dates_not_in_past
    return if valid_from.blank? && valid_until.blank?

    errors.add(:valid_from, "cannot be in the past") if valid_from.present? && valid_from < Date.current
    errors.add(:valid_until, "cannot be in the past") if valid_until.present? && valid_until < Date.current
  end

  def no_overlapping_discounts
    return if customer_id.blank? || product_id.blank?

    overlapping = CustomerProductDiscount
      .where(customer_id: customer_id, product_id: product_id)
      .where.not(id: id)

    if valid_from.present? && valid_until.present?
      overlapping = overlapping.where(
        "(valid_from IS NULL OR valid_from <= ?) AND (valid_until IS NULL OR valid_until >= ?)",
        valid_until, valid_from
      )
    elsif perpetual?
      # Perpetual discount - check if any other discount exists
      overlapping = overlapping.all
    end

    if overlapping.exists?
      errors.add(:base, "overlaps with an existing discount for this customer and product")
    end
  end
end
