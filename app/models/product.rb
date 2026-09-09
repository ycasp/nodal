class Product < ApplicationRecord
  include Slugable
  include HasExportableColumns

  # Storefront sort options exposed in the products listing dropdown.
  # Reused by Organisation and Category to validate their default_product_sort.
  SORT_OPTIONS = %w[name_asc name_desc price_asc price_desc newest].freeze

  # How the storefront product page renders add-to-cart. "default" keeps the
  # current variant-selector flow; "grid" shows every visible variant as a row
  # with its own qty input and one shared bulk-add button.
  ADD_TO_CART_MODES = %w[default grid].freeze

  # How min_quantity is enforced across a product's variants:
  #   per_variant — each variant line must meet the minimum on its own
  #   combined    — the minimum is the sum of the product's variants in the cart
  MIN_QUANTITY_SCOPES = %w[per_variant combined].freeze

  slugify :name, secondary: :sku

  belongs_to :organisation
  belongs_to :category, optional: true  # Legacy direct association
  has_many :order_items, dependent: :restrict_with_error
  has_many :orders, through: :order_items
  has_many :unmet_demands, dependent: :destroy
  has_many :unmet_demand_occurrences, dependent: :destroy
  has_many :customer_product_discounts, dependent: :destroy
  has_many :product_discounts, dependent: :destroy

  # Many-to-many categories relationship
  has_many :category_products, dependent: :destroy
  has_many :categories, through: :category_products

  # Related products
  has_many :related_product_associations, class_name: "RelatedProduct", dependent: :destroy
  has_many :manual_related_products, through: :related_product_associations, source: :related_product
  has_many :inverse_related_product_associations, class_name: "RelatedProduct",
           foreign_key: :related_product_id, dependent: :destroy

  # Variants and attributes
  has_many :product_variants, dependent: :destroy
  has_many :product_product_attributes, dependent: :destroy
  has_many :product_attributes, through: :product_product_attributes
  has_many :product_available_values, dependent: :destroy
  has_many :available_attribute_values, through: :product_available_values, source: :product_attribute_value

  has_many_attached :photos
  has_rich_text :rich_description

  # Returns the cover photo if set, otherwise falls back to first photo
  def photo
    if cover_photo_blob_id.present?
      photos.find { |p| p.blob_id == cover_photo_blob_id } || photos.first
    else
      photos.first
    end
  end

  # Check if any photos are attached
  def photo_attached?
    photos.attached? && photos.any?
  end

  # Returns a display photo, falling back to variant photos for variable products
  def display_photo
    return photo if photo_attached?
    return nil unless has_variants?

    product_variants.where(is_default: false).each do |v|
      return v.photo if v.photo.attached?
    end
    nil
  end

  # Aggregates product photos + variant photos (for variable products)
  def all_photos
    result = photos.to_a
    if has_variants?
      product_variants.where(is_default: false).each do |v|
        result << v.photo if v.photo.attached?
      end
    end
    result
  end

  validates :slug, uniqueness: true
  validates :name, presence: true
  validates :add_to_cart_mode, inclusion: { in: ADD_TO_CART_MODES }
  validates :min_quantity_scope, inclusion: { in: MIN_QUANTITY_SCOPES }
  monetize :unit_price, as: :price, allow_nil: true

  before_save :sync_description_columns
  after_create :create_default_variant
  after_update :sync_default_variant, if: :should_sync_default_variant?
  after_update :clear_default_variant_for_variable, if: :became_variable?
  after_update :promote_default_variant_for_simple, if: :became_simple?

  scope :simple, -> { where(has_variants: false) }
  scope :variable, -> { where(has_variants: true) }

  # Products carrying an active campaign discount — a product-level OR a
  # category-level ProductDiscount (matching the storefront "PROMOÇÃO" badge).
  # A category discount covers that category AND its descendants (subtree).
  # Products whose sellable variants were all excluded from the discount
  # (exclude_from_discounts) are dropped, since they'd appear in the campaign
  # listing without ever receiving the price. Customer-independent: product/
  # category discounts are global; per-customer special prices are separate.
  # Chain onto an org-scoped relation (e.g. organisation.products.on_promotion).
  scope :on_promotion, -> {
    active = ProductDiscount.active
    direct = active.where.not(product_id: nil).select(:product_id)

    discounted_category_ids = active.where.not(category_id: nil).distinct.pluck(:category_id)
    subtree_ids = Category.where(id: discounted_category_ids).flat_map(&:subtree_ids).uniq
    via_category = CategoryProduct.where(category_id: subtree_ids).select(:product_id)

    # At least one sellable variant must be able to receive the discount: a
    # simple product's default variant, or a variable product's non-default
    # variants, with exclude_from_discounts off.
    with_eligible_variant = ProductVariant.joins(:product)
      .where(exclude_from_discounts: [nil, false])
      .where("(products.has_variants AND NOT product_variants.is_default) OR (NOT products.has_variants AND product_variants.is_default)")
      .select(:product_id)

    where(id: direct).or(where(id: via_category)).where(id: with_eligible_variant)
  }

  def self.exportable_columns
    [
      { key: :name, label: I18n.t("bo.export.columns.product.name"), default: true,
        value: ->(r) { r.name } },
      { key: :sku, label: I18n.t("bo.export.columns.product.sku"), default: true,
        value: ->(r) { r.sku } },
      { key: :description, label: I18n.t("bo.export.columns.product.description"), default: false,
        value: ->(r) { r.rich_description.body&.to_plain_text.presence || r.description } },
      { key: :unit_price, label: I18n.t("bo.export.columns.product.unit_price"), default: true,
        value: ->(r) { r.price&.format } },
      { key: :price_on_request, label: I18n.t("bo.export.columns.product.price_on_request"), default: false,
        value: ->(r) { r.price_on_request? ? I18n.t("bo.common.yes") : I18n.t("bo.common.no") } },
      { key: :published, label: I18n.t("bo.export.columns.product.published"), default: true,
        value: ->(r) { r.published? ? I18n.t("bo.common.yes") : I18n.t("bo.common.no") } },
      { key: :product_type, label: I18n.t("bo.export.columns.product.product_type"), default: true,
        value: ->(r) { r.has_variants? ? I18n.t("bo.products.index.table.variable") : I18n.t("bo.products.index.table.simple") } },
      { key: :categories, label: I18n.t("bo.export.columns.product.categories"), default: true,
        value: ->(r) { r.categories.map(&:name).join(", ") } },
      { key: :min_quantity, label: I18n.t("bo.export.columns.product.min_quantity"), default: false,
        value: ->(r) { r.min_quantity } },
      { key: :unit_description, label: I18n.t("bo.export.columns.product.unit_description"), default: false,
        value: ->(r) { r.unit_description } },
      { key: :created_at, label: I18n.t("bo.export.columns.product.created_at"), default: false,
        value: ->(r) { I18n.l(r.created_at, format: :short) } }
    ]
  end


  def active_discount_for(customer)
    return nil unless customer
    # Direct customer match takes precedence
    direct = customer_product_discounts.active.find_by(customer: customer)
    return direct if direct

    # Fall back to customer category match
    if customer.customer_category_id.present?
      customer_product_discounts.active.find_by(customer_category_id: customer.customer_category_id)
    end
  end

  def show_related_products?
    organisation.show_related_products? && !hide_related_products?
  end

  # Whether to print this product's SKU on storefront listing cards: the org
  # opts in, and the product hasn't individually suppressed it.
  def show_sku_on_card?
    organisation.show_product_sku_on_card? && !hide_sku_on_card?
  end

  def discounted_price_for(discount)
    return price unless discount
    price - (price * discount.discount_value)
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

  # Enforced minimum order quantity, or nil when there's no real minimum.
  def enforced_min_quantity
    min = min_quantity.to_i
    min > 1 ? min : nil
  end

  # True when the minimum is the sum of the product's variants (combined),
  # rather than per-variant. Only meaningful for variable products.
  def min_quantity_combined?
    min_quantity_scope == "combined" && has_variants?
  end

  # For combined minimums: can the customer ever reach the minimum given the
  # variants' stock + backorder capability? When false, the minimum is waived
  # (the customer may buy up to available stock — no dead-end at checkout).
  def combined_min_reachable?
    min = enforced_min_quantity
    return true unless min

    total = product_variants.where(is_default: false)
                            .select(&:purchasable?)
                            .sum(&:max_sellable_quantity)
    total >= min
  end

  # Minimum value for a single quantity input. Combined-scope products allow any
  # positive quantity per line (the total is checked across lines), so the floor
  # is 1; otherwise it's the product minimum.
  def quantity_input_min
    return 1 if min_quantity_combined?

    [min_quantity.to_i, 1].max
  end

  # Human label for the minimum value, e.g. "10 caixas" or "10" — nil when none.
  def minimum_quantity_label
    min = enforced_min_quantity
    return nil unless min

    [min, (min_quantity_type.presence || unit_description.presence)].compact.join(" ").strip
  end

  def variable?
    has_variants?
  end

  # True when the storefront should render the bulk-add grid instead of the
  # standard variant selector. Only meaningful for products with variants.
  def grid_add_to_cart?
    add_to_cart_mode == "grid" && has_variants?
  end

  def purchasable?
    return false if price_on_request?
    variants = product_variants.published
    variants = variants.where(is_default: false) if has_variants? && product_variants.where(is_default: false).exists?
    variants.any?(&:purchasable?)
  end

  def price_range
    variants = product_variants.published
    # Exclude default base variant from range calculation for variable products
    variants = variants.where(is_default: false) if has_variants? && product_variants.where(is_default: false).exists?
    # Exclude variants hidden in the storefront (out of stock + hide policy)
    visible = variants.to_a.select { |v| v.available? || v.effective_stock_policy != 'hide' }
    prices = visible.map(&:unit_price_cents).compact
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

  # Discounted price range for a variable product, evaluated at the cheapest and
  # the most-expensive visible variant. The per-unit final price is monotonic in
  # the base price, so these two endpoints give the exact range — unlike
  # extrapolating a single percentage, which is wrong for fixed (non-uniform)
  # discounts (e.g. €10 off is 83% of €12 but only 23% of €43). Returns a hash
  # of Money values, or nil when there are no visible priced variants.
  # Conditions are evaluated at the minimum purchase quantity by default (the
  # customer can never buy fewer), so a "from €100" discount that the min order
  # already clears shows the discounted unit price — not the undiscounted one.
  def discounted_price_range(customer, for_display: true, cart_context: nil, quantity: quantity_input_min)
    @discounted_price_range ||= {}
    @discounted_price_range[[ customer&.id, for_display, quantity ]] ||= compute_discounted_price_range(customer, for_display, cart_context, quantity)
  end

  def compute_discounted_price_range(customer, for_display, cart_context, quantity)
    variants = product_variants.where(is_default: false, published: true)
                               .where.not(unit_price_cents: [ nil, 0 ]).to_a
                               .select { |v| v.available? || v.effective_stock_policy != "hide" }
    return nil if variants.empty?

    cheapest = variants.min_by(&:unit_price_cents)
    priciest = variants.max_by(&:unit_price_cents)
    finals = [ cheapest, priciest ].uniq.map do |v|
      DiscountCalculator.new(product: self, customer: customer, quantity: quantity, for_display: for_display, variant: v, cart_context: cart_context).final_price
    end

    {
      original_min: cheapest.price, original_max: priciest.price,
      final_min: finals.min, final_max: finals.max,
      range: cheapest.unit_price_cents != priciest.unit_price_cents
    }
  end

  def available_values_by_attribute
    product_attributes.by_position.each_with_object({}) do |attribute, hash|
      hash[attribute] = available_attribute_values
        .joins(:product_attribute)
        .where(product_attributes: { id: attribute.id })
        .includes(:product_attribute)
        .naturally_sorted
    end
  end

  def find_variant_by_attribute_values(attribute_value_ids)
    return default_variant if attribute_value_ids.blank?

    product_variants.find do |variant|
      variant.attribute_values.pluck(:id).sort == attribute_value_ids.map(&:to_i).sort
    end
  end

  private

  # Mirrors content between rich_description (Trix-edited) and the legacy
  # description column. When the form edits rich, description follows.
  # When imports/ERP sync set description directly, rich gets backfilled.
  # The body_changed? check distinguishes form path from import path so
  # clearing the rich editor doesn't get reverted from a stale description.
  def sync_description_columns
    if rich_description.body_changed?
      self.description = rich_description.body&.to_plain_text&.strip.presence
    elsif description_changed? && description.present?
      self.rich_description = description
    end
  end

  def create_default_variant
    return if product_variants.exists?

    if has_variants?
      product_variants.create!(
        name: name,
        unit_price_currency: organisation.currency,
        published: published,
        is_default: true,
        track_stock: false,
        position: 1
      )
    else
      product_variants.create!(
        name: name,
        sku: sku,
        unit_price_cents: unit_price,
        unit_price_currency: organisation.currency,
        published: published,
        is_default: true,
        position: 1
      )
    end
  end

  def should_sync_default_variant?
    !has_variants? && (saved_change_to_name? || saved_change_to_unit_price? || saved_change_to_sku? || saved_change_to_published?)
  end

  def sync_default_variant
    variant = default_variant
    return unless variant&.is_default?

    variant.update(
      name: name,
      sku: sku,
      unit_price_cents: unit_price,
      published: published
    )
  end

  def became_variable?
    saved_change_to_has_variants? && has_variants?
  end

  def became_simple?
    saved_change_to_has_variants? && !has_variants?
  end

  # When a variable product is reclassified as simple, the price lived on the
  # variant (product.unit_price stays nil for variable products). The mirror
  # callback only fires on a variant price *change*, so a pure has_variants
  # flip would leave product.unit_price stale (nil) — and the storefront, which
  # reads product.unit_price, would show €0. Promote the default variant's
  # commercial fields up to the product to keep them in sync.
  def promote_default_variant_for_simple
    variant = default_variant
    return unless variant

    update_columns(unit_price: variant.unit_price_cents, sku: variant.sku)
  end

  def clear_default_variant_for_variable
    variant = default_variant
    return unless variant&.is_default?

    variant.update_columns(
      sku: nil,
      unit_price_cents: nil,
      stock_quantity: 0,
      track_stock: false,
      external_id: nil,
      external_source: nil
    )
    update_columns(unit_price: nil)
  end
end
