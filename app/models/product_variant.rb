class ProductVariant < ApplicationRecord
  include ErpSyncable
  include HasExportableColumns

  belongs_to :organisation
  belongs_to :product
  has_many :variant_attribute_values, dependent: :destroy
  has_many :attribute_values, through: :variant_attribute_values, source: :product_attribute_value
  has_many :order_items, dependent: :restrict_with_error
  has_many :unmet_demands, dependent: :nullify
  has_many :unmet_demand_occurrences, dependent: :nullify
  has_many :stock_events, dependent: :destroy

  has_one_attached :photo

  acts_as_list scope: :product

  monetize :unit_price_cents, as: :price, allow_nil: true

  validates :name, presence: true
  validates :sku, uniqueness: { scope: :organisation_id, allow_blank: true }
  validates :custom_discount_type, inclusion: { in: %w[percentage fixed] }, allow_blank: true
  validates :custom_discount_value, presence: true, if: -> { custom_discount_type.present? }
  validates :custom_discount_type, presence: true, if: -> { custom_discount_value.present? }
  validates :custom_discount_value, numericality: { greater_than: 0 }, allow_nil: true

  before_validation :normalize_custom_discount_fields
  before_validation :set_organisation_from_product
  before_validation :set_currency_from_organisation
  before_validation :inherit_product_price, on: :create
  after_save :mirror_to_product, if: :should_mirror_to_product?

  scope :by_position, -> { order(:position) }
  scope :available, -> { where(available: true) }
  scope :published, -> { where(published: true) }
  scope :default, -> { where(is_default: true) }

  # Stock-control (risk) scopes — tracked variants only; untracked ones sell
  # without stock so they carry no risk.
  scope :stock_tracked,    -> { where(track_stock: true) }
  scope :stock_out,        -> { stock_tracked.where("stock_quantity <= 0") }
  scope :stock_at_risk,    ->(threshold) { stock_tracked.where("stock_quantity > 0 AND stock_quantity <= ?", threshold) }
  scope :stock_low_or_out, ->(threshold) { stock_tracked.where("stock_quantity <= ?", threshold) }
  # The placeholder base variant of a variable product isn't a real sellable
  # unit — exclude it from stock listings.
  scope :real_units, -> { joins(:product).where("NOT (product_variants.is_default AND products.has_variants)") }

  def self.exportable_columns
    [
      { key: :product_name, label: I18n.t("bo.export.columns.variant.product_name"), default: true,
        value: ->(r) { r.product&.name } },
      { key: :variant_name, label: I18n.t("bo.export.columns.variant.variant_name"), default: true,
        value: ->(r) { r.name } },
      { key: :options, label: I18n.t("bo.export.columns.variant.options"), default: true,
        value: ->(r) { r.option_values_string.presence } },
      { key: :sku, label: I18n.t("bo.export.columns.variant.sku"), default: true,
        value: ->(r) { r.sku } },
      { key: :unit_price, label: I18n.t("bo.export.columns.variant.unit_price"), default: true,
        value: ->(r) { r.price&.format } },
      { key: :published, label: I18n.t("bo.export.columns.variant.published"), default: true,
        value: ->(r) { r.published? ? I18n.t("bo.common.yes") : I18n.t("bo.common.no") } },
      { key: :stock_quantity, label: I18n.t("bo.export.columns.variant.stock_quantity"), default: true,
        value: ->(r) { r.track_stock? ? r.stock_quantity : I18n.t("bo.export.columns.variant.unlimited") } },
      { key: :track_stock, label: I18n.t("bo.export.columns.variant.track_stock"), default: false,
        value: ->(r) { r.track_stock? ? I18n.t("bo.common.yes") : I18n.t("bo.common.no") } },
      { key: :is_default, label: I18n.t("bo.export.columns.variant.is_default"), default: false,
        value: ->(r) { r.is_default? ? I18n.t("bo.common.yes") : I18n.t("bo.common.no") } },
      { key: :categories, label: I18n.t("bo.export.columns.variant.categories"), default: false,
        value: ->(r) { r.product&.categories&.map(&:name)&.join(", ") } },
      { key: :product_type, label: I18n.t("bo.export.columns.variant.product_type"), default: false,
        value: ->(r) { r.product&.has_variants? ? I18n.t("bo.products.index.table.variable") : I18n.t("bo.products.index.table.simple") } }
    ]
  end

  STOCK_POLICIES = %w[inherit track_only show_badge hide].freeze

  validates :stock_policy, inclusion: { in: STOCK_POLICIES }

  def effective_stock_policy
    return stock_policy unless stock_policy == 'inherit'
    case organisation.out_of_stock_strategy
    when 'do_nothing' then 'track_only'
    when 'deactivate' then 'show_badge'
    when 'hide' then 'hide'
    else 'track_only'
    end
  end

  def in_stock?
    return true unless track_stock?
    stock_quantity.to_i > 0
  end

  def purchasable?
    return false unless published? && !product.price_on_request?
    return true if effective_stock_policy == 'track_only'
    in_stock?
  end

  # True when this variant can be sold beyond its stock (untracked or backorder).
  def sells_without_stock?
    !track_stock? || effective_stock_policy == 'track_only'
  end

  # Upper bound of how many units can be sold: unlimited for backorder/untracked
  # variants, otherwise the current stock. Used to decide whether a minimum
  # order quantity is reachable (and therefore enforceable).
  def max_sellable_quantity
    sells_without_stock? ? Float::INFINITY : stock_quantity.to_i
  end

  def option_values_string
    # Sort in Ruby off the (often preloaded) association rather than .joins/.order,
    # which would fire a fresh query per variant and defeat eager loading.
    attribute_values.sort_by { |av| av.product_attribute.position }.map(&:value).join(' / ')
  end

  # Sort key for natural ordering by option name: numeric chunks compare
  # numerically (so "100" sorts after "20"), text chunks alphabetically.
  # Mirrors ProductAttributeValue.naturally_sorted, applied per attribute in
  # configured position order so multi-attribute variants order sensibly.
  def natural_sort_key
    attribute_values.sort_by { |av| av.product_attribute.position }.map do |av|
      av.value.to_s.downcase.scan(/\d+\.?\d*|\D+/).map do |chunk|
        chunk.match?(/\A\d/) ? [0, chunk.to_f] : [1, chunk]
      end
    end
  end

  def display_name
    if is_default? && attribute_values.empty?
      product.name
    else
      "#{product.name} - #{option_values_string}"
    end
  end

  # Disambiguating label for pickers: full variant name plus SKU.
  def picker_label
    sku.present? ? "#{display_name} — #{sku}" : display_name
  end

  # Risk classification for the BO stock-control list.
  #   :untracked   — sells without stock, no risk
  #   :out_of_stock — tracked, nothing on hand
  #   :at_risk     — tracked, at/under the org's low-stock threshold
  #   :ok          — tracked, comfortably stocked
  def stock_control_status(threshold)
    return :untracked unless track_stock?

    qty = stock_quantity.to_i
    return :out_of_stock if qty <= 0
    return :at_risk if qty <= threshold.to_i

    :ok
  end

  def has_custom_discount?
    custom_discount_type.present? && custom_discount_value.present?
  end

  def effective_photo
    return photo if photo.attached?
    return product.photo if product.photo_attached?
    nil
  end

  private

  def normalize_custom_discount_fields
    self.custom_discount_type = nil if custom_discount_type.blank?
    self.custom_discount_value = nil if custom_discount_value.blank?
  end

  def set_organisation_from_product
    self.organisation ||= product&.organisation
  end

  def set_currency_from_organisation
    self.unit_price_currency ||= organisation&.currency || 'EUR'
  end

  def inherit_product_price
    self.unit_price_cents ||= product&.unit_price
  end

  def should_mirror_to_product?
    is_default? && product&.simple? && (saved_change_to_sku? || saved_change_to_unit_price_cents? || saved_change_to_published?)
  end

  def mirror_to_product
    attrs = {}
    attrs[:sku] = sku if saved_change_to_sku?
    attrs[:unit_price] = unit_price_cents if saved_change_to_unit_price_cents?
    attrs[:published] = published if saved_change_to_published?
    product.update_columns(attrs) if attrs.any?
  end
end
