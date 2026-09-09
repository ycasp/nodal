class Category < ApplicationRecord
  include Discard::Model

  has_ancestry cache_depth: true

  acts_as_list scope: [:organisation_id, :ancestry]

  has_one_attached :photo

  belongs_to :organisation
  has_many :category_products, dependent: :destroy
  has_many :products, through: :category_products
  has_many :product_discounts, dependent: :destroy
  has_many :customer_product_discounts, dependent: :destroy

  # Keep legacy direct association for backward compatibility
  has_many :direct_products, class_name: 'Product', foreign_key: 'category_id'

  validates :name, presence: true
  validates :name, uniqueness: { case_sensitive: false, scope: [:organisation_id, :ancestry] }
  validates :slug, uniqueness: { scope: :organisation_id, allow_blank: true }
  validates :default_product_sort, inclusion: { in: Product::SORT_OPTIONS }, allow_blank: true
  # Kept strict: this value is interpolated into a style attribute in the storefront nav.
  validates :color, format: { with: /\A#(\h{3}|\h{6})\z/ }, allow_blank: true
  validate :prevent_self_ancestry

  scope :active, -> { kept }
  scope :published, -> { where(published: true) }
  # Categories a customer may see listed in the storefront navigation.
  scope :visible, -> { kept.published }
  scope :roots, -> { where(ancestry: nil) }
  scope :by_position, -> { order(:position) }

  # Preset palette offered in the BO form. Free-form hex is still accepted, but
  # these are picked to stay legible as text on the storefront's light surfaces.
  NAV_COLORS = %w[
    #6c757d #212529 #0d6efd #6f42c1 #d63384 #dc3545 #fd7e14 #198754
  ].freeze

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

  # Inline style for the category's label in the storefront navigation
  # (sidebar links and mobile chips). Returns nil when the org left the
  # defaults alone, so we don't emit an empty style attribute.
  def nav_style
    styles = []
    styles << "color: #{color}" if color.present?
    styles << "font-weight: 600" if nav_bold?
    styles << "font-style: italic" if nav_italic?
    styles.join("; ").presence
  end

  def depth_warning?
    depth >= 5
  end

  def full_path
    ancestors.map(&:name).push(name).join(' > ')
  end

  def self.sorted_by_full_path
    all.sort_by(&:full_path)
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

    # Trim only. This used to force Title Case (`downcase.titleize`), which made
    # deliberate casing impossible to save — ALL CAPS came back title-cased and
    # acronyms were mangled ("PVD" -> "Pvd"). Uniqueness is already
    # case-insensitive, and the import services look categories up
    # case-insensitively too, so nothing depends on the normalised form.
    self.name = name.strip
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
