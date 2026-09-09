class ProductAttribute < ApplicationRecord
  include Discard::Model

  belongs_to :organisation
  has_many :product_attribute_values, dependent: :destroy
  has_many :product_product_attributes, dependent: :destroy
  has_many :products, through: :product_product_attributes

  acts_as_list scope: :organisation

  accepts_nested_attributes_for :product_attribute_values, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :organisation_id }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :by_position, -> { order(:position) }
  scope :active, -> { where(active: true) }

  def to_s
    name
  end

  private

  def generate_slug
    base_slug = name.parameterize
    slug_candidate = base_slug
    counter = 1

    while organisation.product_attributes.where(slug: slug_candidate).where.not(id: id).exists?
      counter += 1
      slug_candidate = "#{base_slug}-#{counter}"
    end

    self.slug = slug_candidate
  end
end
