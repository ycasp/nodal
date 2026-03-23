class CustomerProductDiscount < ApplicationRecord
  include HasEmailNotification

  DISCOUNT_TYPES = %w[percentage fixed].freeze

  belongs_to :customer, optional: true
  belongs_to :customer_category, optional: true
  belongs_to :product, optional: true
  belongs_to :category, optional: true
  belongs_to :organisation

  validates :discount_type, presence: true, inclusion: { in: DISCOUNT_TYPES }
  validates :discount_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  validate :valid_until_after_valid_from
  validate :dates_not_in_past, on: :create
  validate :no_overlapping_discounts
  validate :must_have_product_or_category
  validate :must_have_customer_or_customer_category

  scope :active, -> {
    where(active: true)
      .where("(valid_from IS NULL OR valid_from <= ?) AND (valid_until IS NULL OR valid_until >= ?)",
             Date.current, Date.current)
  }

  scope :for_product, -> { where.not(product_id: nil) }
  scope :for_category, -> { where.not(category_id: nil) }

  def percentage?
    discount_type == 'percentage'
  end

  def fixed?
    discount_type == 'fixed'
  end

  def perpetual?
    valid_from.nil? && valid_until.nil?
  end

  def product?
    product_id.present?
  end

  def category?
    category_id.present?
  end

  def category_based?
    customer_category_id.present?
  end

  def customer_target_name
    if category_based?
      customer_category&.name
    else
      customer&.company_name
    end
  end

  def target_name
    if product?
      product.name
    elsif category?
      category.full_path
    end
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
    return if customer_id.blank? && customer_category_id.blank?
    return if product_id.blank? && category_id.blank?

    overlapping = CustomerProductDiscount.where.not(id: id)

    if customer_id.present?
      overlapping = overlapping.where(customer_id: customer_id)
    else
      overlapping = overlapping.where(customer_category_id: customer_category_id)
    end

    if product?
      overlapping = overlapping.where(product_id: product_id)
    else
      overlapping = overlapping.where(category_id: category_id)
    end

    if valid_from.present? && valid_until.present?
      overlapping = overlapping.where(
        "(valid_from IS NULL OR valid_from <= ?) AND (valid_until IS NULL OR valid_until >= ?)",
        valid_until, valid_from
      )
    elsif perpetual?
      overlapping = overlapping.all
    end

    if overlapping.exists?
      target = product? ? "product" : "category"
      errors.add(:base, "overlaps with an existing discount for this customer and #{target}")
    end
  end

  def must_have_customer_or_customer_category
    if customer_id.blank? && customer_category_id.blank?
      errors.add(:base, "must target either a customer or a customer category")
    elsif customer_id.present? && customer_category_id.present?
      errors.add(:base, "cannot target both a customer and a customer category")
    end
  end

  def must_have_product_or_category
    if product_id.blank? && category_id.blank?
      errors.add(:base, "must target either a product or a category")
    elsif product_id.present? && category_id.present?
      errors.add(:base, "cannot target both a product and a category")
    end
  end
end
