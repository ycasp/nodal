class CustomerProductDiscount < ApplicationRecord
  belongs_to :customer
  belongs_to :product
  belongs_to :organisation

  validates :discount_percentage, numericality: { greater_than_or_equal_to: 0,
    less_than_or_equal_to: 1 }
  validates :valid_from, presence: true
  validates :valid_until, presence: true

  validate :valid_until_after_valid_from
  validate :dates_not_in_past, on: :create
  validate :no_overlapping_discounts

  private

  def valid_until_after_valid_from
    return if valid_from.blank? || valid_until.blank?

    if valid_until < valid_from
      errors.add(:valid_until, "must be after valid from date")
    end
  end

  def dates_not_in_past
    return if valid_from.blank? || valid_until.blank?

    errors.add(:valid_from, "cannot be in the past") if valid_from < Date.current
    errors.add(:valid_until, "cannot be in the past") if valid_until < Date.current
  end

  def no_overlapping_discounts
    return if customer_id.blank? || product_id.blank? || valid_from.blank? || valid_until.blank?

    overlapping = CustomerProductDiscount
      .where(customer_id: customer_id, product_id: product_id)
      .where.not(id: id)
      .where("valid_from <= ? AND valid_until >= ?", valid_until, valid_from)

    if overlapping.exists?
      errors.add(:base, "overlaps with an existing discount for this customer and product")
    end
  end
end
