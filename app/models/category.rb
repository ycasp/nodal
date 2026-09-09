class Category < ApplicationRecord
  include Discard::Model

  has_ancestry cache_depth: true

  acts_as_list scope: [:organisation_id, :ancestry]

  belongs_to :organisation
  has_many :category_products, dependent: :destroy
  has_many :products, through: :category_products

  # Keep legacy direct association for backward compatibility
  has_many :direct_products, class_name: 'Product', foreign_key: 'category_id'

  validates :name, presence: true
  validates :name, uniqueness: { case_sensitive: false, scope: [:organisation_id, :ancestry] }
  validates :slug, uniqueness: { scope: :organisation_id, allow_blank: true }
  validate :prevent_self_ancestry

  scope :active, -> { kept }
  scope :roots, -> { where(ancestry: nil) }
  scope :by_position, -> { order(:position) }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  before_save :normalize_name
  before_discard :check_children
  before_discard :remove_product_associations

  # Get all products from this category and all descendants
  def all_products
    Product.joins(:category_products)
           .where(category_products: { category_id: subtree_ids })
           .distinct
  end

  def all_products_count
    all_products.count
  end

  def direct_products_count
    products.count
  end

  def deletable?
    children.kept.empty?
  end

  def depth_warning?
    depth >= 5
  end

  def full_path
    ancestors.map(&:name).push(name).join(' > ')
  end

  private

  def generate_slug
    base_slug = name.parameterize
    slug_candidate = base_slug
    counter = 1

    while organisation.categories.where.not(id: id).exists?(slug: slug_candidate)
      slug_candidate = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = slug_candidate
  end

  def normalize_name
    return if name.blank?

    self.name = name.strip.downcase.titleize
  end

  def prevent_self_ancestry
    return unless ancestry.present? && id.present?

    if ancestor_ids.include?(id)
      errors.add(:ancestry, "cannot include self as ancestor")
    end
  end

  def check_children
    if children.kept.any?
      errors.add(:base, "Cannot delete category with subcategories")
      throw :abort
    end
  end

  def remove_product_associations
    category_products.destroy_all
  end
end
