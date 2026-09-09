class ProductVariant < ApplicationRecord
  include ErpSyncable

  belongs_to :organisation
  belongs_to :product
  has_many :variant_attribute_values, dependent: :destroy
  has_many :attribute_values, through: :variant_attribute_values, source: :product_attribute_value
  has_many :order_items, dependent: :restrict_with_error

  has_one_attached :photo

  acts_as_list scope: :product

  monetize :unit_price_cents, as: :price, allow_nil: true

  validates :name, presence: true
  validates :sku, uniqueness: { scope: :organisation_id, allow_blank: true }

  before_validation :set_organisation_from_product
  before_validation :set_currency_from_organisation
  before_validation :inherit_product_price, on: :create

  scope :by_position, -> { order(:position) }
  scope :available, -> { where(available: true) }
  scope :default, -> { where(is_default: true) }

  def in_stock?
    return true unless track_stock?
    stock_quantity.to_i > 0
  end

  def purchasable?
    available? && in_stock?
  end

  def option_values_string
    attribute_values.joins(:product_attribute).order('product_attributes.position').map(&:value).join(' / ')
  end

  def display_name
    if is_default? && attribute_values.empty?
      product.name
    else
      "#{product.name} - #{option_values_string}"
    end
  end

  def effective_photo
    return photo if photo.attached?
    return product.photo if product.photo_attached?
    nil
  end

  private

  def set_organisation_from_product
    self.organisation ||= product&.organisation
  end

  def set_currency_from_organisation
    self.unit_price_currency ||= organisation&.currency || 'EUR'
  end

  def inherit_product_price
    self.unit_price_cents ||= product&.unit_price
  end
end
