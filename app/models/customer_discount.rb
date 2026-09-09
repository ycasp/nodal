class CustomerDiscount < ApplicationRecord
  include HasEmailNotification

  DISCOUNT_TYPES = %w[percentage fixed].freeze

  belongs_to :customer, optional: true
  belongs_to :customer_category, optional: true
  belongs_to :organisation

  validates :discount_type, presence: true, inclusion: { in: DISCOUNT_TYPES }
  validates :discount_value, presence: true, numericality: { greater_than: 0 }

  validate :discount_value_valid_for_type
  validate :valid_until_after_valid_from
  validate :no_overlapping_discounts
  validate :must_have_customer_or_category

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

  def category_based?
    customer_category_id.present?
  end

  def target_name
    if category_based?
      customer_category&.name
    else
      customer&.company_name
    end
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
    return if customer_id.blank? && customer_category_id.blank?

    overlapping = CustomerDiscount.where.not(id: id)

    if customer_id.present?
      overlapping = overlapping.where(customer_id: customer_id)
    else
      overlapping = overlapping.where(customer_category_id: customer_category_id)
    end

    if valid_from.present? && valid_until.present?
      overlapping = overlapping.where(
        "(valid_from IS NULL OR valid_from <= ?) AND (valid_until IS NULL OR valid_until >= ?)",
        valid_until, valid_from
      )
    elsif perpetual?
      overlapping = overlapping.all
    else
      if valid_from.nil?
        overlapping = overlapping.where("valid_until IS NULL OR valid_until >= ?", Date.current)
      else
        overlapping = overlapping.where("valid_from IS NULL OR valid_from <= ?", valid_until || Date.current + 100.years)
      end
    end

    target = customer_id.present? ? "customer" : "customer category"
    errors.add(:base, "overlaps with an existing discount for this #{target}") if overlapping.exists?
  end

  def must_have_customer_or_category
    if customer_id.blank? && customer_category_id.blank?
      errors.add(:base, "must target either a customer or a customer category")
    elsif customer_id.present? && customer_category_id.present?
      errors.add(:base, "cannot target both a customer and a customer category")
    end
  end
end
