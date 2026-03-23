class ProductDiscount < ApplicationRecord
  include HasEmailNotification

  DISCOUNT_TYPES = %w[percentage fixed].freeze

  belongs_to :product, optional: true
  belongs_to :category, optional: true
  belongs_to :organisation

  validates :discount_type, presence: true, inclusion: { in: DISCOUNT_TYPES }
  validates :discount_value, presence: true, numericality: { greater_than: 0 }
  validates :min_quantity, presence: true, numericality: { greater_than_or_equal_to: 1, only_integer: true }

  validate :discount_value_valid_for_type
  validate :valid_until_after_valid_from
  validate :min_quantity_not_below_product_minimum
  validate :must_have_product_or_category

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

  # Display name: product name or category path
  def target_name
    if product?
      product.name
    elsif category?
      category.full_path
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

  def min_quantity_not_below_product_minimum
    return unless product? && product.present? && min_quantity.present?

    product_min = product.min_quantity || 1
    if min_quantity < product_min
      errors.add(:min_quantity, "cannot be less than the product's minimum order quantity (#{product_min})")
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
