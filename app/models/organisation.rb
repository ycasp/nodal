class Organisation < ApplicationRecord
  include Slugable

  SUPPORTED_CURRENCIES = %w[EUR CHF USD GBP].freeze
  HEX_COLOR_REGEX = /\A#[0-9A-Fa-f]{6}\z/

  monetize :shipping_cost_cents
  monetize :free_shipping_threshold_cents, allow_nil: true

  has_one_attached :logo
  has_one_attached :favicon
  has_many :org_members, dependent: :destroy
  has_many :members, through: :org_members, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_one :billing_address, -> { billing }, class_name: "Address", as: :addressable, dependent: :destroy
  has_one :contact_address, -> { contact }, class_name: "Address", as: :addressable, dependent: :destroy

  accepts_nested_attributes_for :contact_address, allow_destroy: true, reject_if: :all_blank
  has_many :categories, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :product_attributes, dependent: :destroy
  has_many :product_variants, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :customer_product_discounts, dependent: :destroy
  has_many :product_discounts, dependent: :destroy
  has_many :customer_discounts, dependent: :destroy
  has_many :order_discounts, dependent: :destroy
  has_one :erp_configuration, dependent: :destroy
  has_many :erp_sync_logs, dependent: :destroy

  validates :name, presence: true
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :currency, presence: true, inclusion: { in: SUPPORTED_CURRENCIES }
  validates :default_locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validates :primary_color, format: { with: HEX_COLOR_REGEX }, allow_blank: true
  validates :secondary_color, format: { with: HEX_COLOR_REGEX }, allow_blank: true

  slugify :name

  def currency_symbol
    Money::Currency.new(currency).symbol
  end

  def free_shipping_enabled?
    free_shipping_threshold_cents.present? && free_shipping_threshold_cents > 0
  end

  def effective_primary_color
    primary_color.presence || '#008060'
  end

  def effective_secondary_color
    secondary_color.presence || '#004c3f'
  end

  def display_contact_address
    if use_billing_address_for_contact?
      billing_address
    else
      contact_address
    end
  end

  def has_contact_info?
    contact_email.present? ||
      phone.present? ||
      whatsapp.present? ||
      business_hours.present? ||
      display_contact_address.present?
  end

  def effective_storefront_title
    storefront_title.presence || name
  end
end
