class ProductAttributeValue < ApplicationRecord
  belongs_to :product_attribute
  has_many :product_available_values, dependent: :destroy
  has_many :products, through: :product_available_values
  has_many :variant_attribute_values, dependent: :destroy
  has_many :product_variants, through: :variant_attribute_values

  acts_as_list scope: :product_attribute

  validates :value, presence: true
  validates :slug, presence: true, uniqueness: { scope: :product_attribute_id }
  validates :color_hex, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: "must be a valid hex color (e.g., #FF5733)" }, allow_blank: true

  before_validation :generate_slug, if: -> { slug.blank? && value.present? }

  scope :by_position, -> { order(:position) }
  scope :active, -> { where(active: true) }

  delegate :organisation, to: :product_attribute

  def to_s
    value
  end

  def display_name
    value
  end

  private

  def generate_slug
    base_slug = value.parameterize
    slug_candidate = base_slug
    counter = 1

    while product_attribute.product_attribute_values.where(slug: slug_candidate).where.not(id: id).exists?
      counter += 1
      slug_candidate = "#{base_slug}-#{counter}"
    end

    self.slug = slug_candidate
  end
end
