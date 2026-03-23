class PromoCode < ApplicationRecord
  include HasEmailNotification

  DISCOUNT_TYPES = %w[percentage fixed].freeze
  ELIGIBILITIES = %w[all_customers specific_customers].freeze

  belongs_to :organisation

  has_many :promo_code_customers, dependent: :destroy
  has_many :eligible_customers, through: :promo_code_customers, source: :customer
  has_many :promo_code_customer_categories, dependent: :destroy
  has_many :eligible_customer_categories, through: :promo_code_customer_categories, source: :customer_category
  has_many :promo_code_redemptions, dependent: :destroy
  has_many :orders

  monetize :min_order_amount_cents, allow_nil: true

  validates :code, presence: true, uniqueness: { scope: :organisation_id, case_sensitive: false }
  validates :discount_type, presence: true, inclusion: { in: DISCOUNT_TYPES }
  validates :discount_value, presence: true, numericality: { greater_than: 0 }
  validates :eligibility, presence: true, inclusion: { in: ELIGIBILITIES }
  validates :per_customer_limit, numericality: { greater_than: 0 }

  validate :discount_value_valid_for_type
  validate :valid_until_after_valid_from

  before_validation :upcase_code

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

  def value_display
    if percentage?
      "#{(discount_value * 100).round(0)}%"
    else
      discount_value
    end
  end

  def valid_period_display
    if valid_from.nil? && valid_until.nil?
      "No expiry"
    elsif valid_from.present? && valid_until.present?
      "#{valid_from.strftime('%Y-%m-%d')} to #{valid_until.strftime('%Y-%m-%d')}"
    elsif valid_from.present?
      "From #{valid_from.strftime('%Y-%m-%d')}"
    elsif valid_until.present?
      "Until #{valid_until.strftime('%Y-%m-%d')}"
    end
  end

  def expired?
    (valid_until.present? && valid_until < Date.current) ||
      (valid_from.present? && valid_from > Date.current)
  end

  def usage_limit_reached?
    usage_limit.present? && usage_count >= usage_limit
  end

  def customer_usage_count(customer)
    promo_code_redemptions.where(customer: customer).count
  end

  def customer_limit_reached?(customer)
    customer_usage_count(customer) >= per_customer_limit
  end

  def eligible_for_customer?(customer)
    return true if eligibility == 'all_customers'
    return true if promo_code_customers.exists?(customer: customer)
    customer.customer_category_id.present? &&
      promo_code_customer_categories.exists?(customer_category_id: customer.customer_category_id)
  end

  def redeemable_by?(customer, order)
    return :inactive unless active?
    return :expired if expired?
    return :usage_limit_reached if usage_limit_reached?
    return :customer_limit_reached if customer_limit_reached?(customer)
    return :not_eligible unless eligible_for_customer?(customer)
    if min_order_amount_cents > 0 && order.total_amount.cents < min_order_amount_cents
      return :min_amount_not_met
    end
    :ok
  end

  def calculate_discount(subtotal)
    if percentage?
      subtotal * discount_value
    else
      Money.new((discount_value * 100).to_i, organisation.currency)
    end
  end

  private

  def upcase_code
    self.code = code&.upcase&.strip
  end

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
end
