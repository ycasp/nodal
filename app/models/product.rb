class Product < ApplicationRecord
  include Slugable
  include ErpSyncable

  slugify :name, secondary: :sku

  belongs_to :organisation
  belongs_to :category, optional: true  # Legacy direct association
  has_many :order_items, dependent: :restrict_with_error
  has_many :orders, through: :order_items
  has_many :customer_product_discounts, dependent: :destroy
  has_many :product_discounts, dependent: :destroy

  # Many-to-many categories relationship
  has_many :category_products, dependent: :destroy
  has_many :categories, through: :category_products

  # Variants and attributes
  has_many :product_variants, dependent: :destroy
  has_many :product_product_attributes, dependent: :destroy
  has_many :product_attributes, through: :product_product_attributes
  has_many :product_available_values, dependent: :destroy
  has_many :available_attribute_values, through: :product_available_values, source: :product_attribute_value

  has_many_attached :photos

  # Backward compatibility: returns first photo
  def photo
    photos.first
  end

  # Check if any photos are attached
  def photo_attached?
    photos.attached? && photos.any?
  end

  validates :slug, uniqueness: true
  validates :name, presence: true
  validates :description, length: { maximum: 150 }, allow_blank: true
  monetize :unit_price, as: :price, allow_nil: true

  after_create :create_default_variant
  after_update :sync_default_variant, if: :should_sync_default_variant?

  scope :simple, -> { where(has_variants: false) }
  scope :variable, -> { where(has_variants: true) }

  def active_discount_for(customer)
    return nil unless customer
    customer_product_discounts.active.find_by(customer: customer)
  end

  def discounted_price_for(discount)
    return price unless discount
    price - (price * discount.discount_percentage)
  end

  # Returns the primary category (first by position) or falls back to legacy category
  def primary_category
    categories.joins(:category_products)
              .order('category_products.position')
              .first || category
  end

  # Variant-related methods

  def default_variant
    product_variants.default.first || product_variants.first
  end

  def simple?
    !has_variants?
  end

  def variable?
    has_variants?
  end

  def purchasable?
    product_variants.available.any?(&:purchasable?)
  end

  def price_range
    prices = product_variants.available.pluck(:unit_price_cents).compact
    return nil if prices.empty?

    min_price = Money.new(prices.min, organisation.currency)
    max_price = Money.new(prices.max, organisation.currency)

    { min: min_price, max: max_price, range: min_price != max_price }
  end

  def display_price
    range = price_range
    return price unless range

    if range[:range]
      "#{range[:min].format} - #{range[:max].format}"
    else
      range[:min].format
    end
  end

  def available_values_by_attribute
    product_attributes.by_position.each_with_object({}) do |attribute, hash|
      hash[attribute] = available_attribute_values
        .joins(:product_attribute)
        .where(product_attributes: { id: attribute.id })
        .includes(:product_attribute)
        .by_position
    end
  end

  def find_variant_by_attribute_values(attribute_value_ids)
    return default_variant if attribute_value_ids.blank?

    product_variants.find do |variant|
      variant.attribute_values.pluck(:id).sort == attribute_value_ids.map(&:to_i).sort
    end
  end

  private

  def create_default_variant
    return if product_variants.exists?

    product_variants.create!(
      name: name,
      sku: sku,
      unit_price_cents: unit_price,
      unit_price_currency: organisation.currency,
      available: available,
      is_default: true,
      position: 1
    )
  end

  def should_sync_default_variant?
    !has_variants? && (saved_change_to_name? || saved_change_to_unit_price? || saved_change_to_sku? || saved_change_to_available?)
  end

  def sync_default_variant
    variant = default_variant
    return unless variant&.is_default?

    variant.update(
      name: name,
      sku: sku,
      unit_price_cents: unit_price,
      available: available
    )
  end
end
