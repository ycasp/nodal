class Organisation < ApplicationRecord
  include Slugable

  SUPPORTED_CURRENCIES = %w[EUR CHF USD GBP].freeze
  OUT_OF_STOCK_STRATEGIES = %w[do_nothing deactivate hide].freeze
  HEX_COLOR_REGEX = /\A#[0-9A-Fa-f]{6}\z/
  CUTOFF_TIME_REGEX = /\A([01]\d|2[0-3]):[0-5]\d\z/
  WEEKDAY_NAMES = %w[sunday monday tuesday wednesday thursday friday saturday].freeze

  monetize :shipping_cost_cents
  monetize :free_shipping_threshold_cents, allow_nil: true

  has_rich_text :terms_and_conditions
  has_rich_text :privacy_policy

  has_one_attached :logo
  has_one_attached :favicon
  has_many :org_members, dependent: :destroy
  has_many :members, through: :org_members, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :customer_categories, dependent: :destroy
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
  has_many :promo_codes, dependent: :destroy
  has_one :erp_configuration, dependent: :destroy
  has_many :erp_sync_logs, dependent: :destroy
  has_many :email_logs, dependent: :destroy
  has_many :discount_email_notifications, dependent: :destroy

  validates :name, presence: true
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :currency, presence: true, inclusion: { in: SUPPORTED_CURRENCIES }
  validates :default_locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validates :out_of_stock_strategy, inclusion: { in: OUT_OF_STOCK_STRATEGIES }
  validates :primary_color, format: { with: HEX_COLOR_REGEX }, allow_blank: true
  validates :secondary_color, format: { with: HEX_COLOR_REGEX }, allow_blank: true
  validates :email_reply_to, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :lead_time_days, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :delivery_days, numericality: { greater_than: 0, only_integer: true }
  validates :order_cutoff_time, format: { with: CUTOFF_TIME_REGEX }, allow_blank: true
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone::MAPPING.values.uniq }

  before_validation :set_delivery_days_from_flags
  before_validation :normalize_cutoff_time

  attr_accessor :delivery_day_flags

  slugify :name

  def currency_symbol
    Money::Currency.new(currency).symbol
  end

  def deactivate_out_of_stock?
    out_of_stock_strategy.in?(%w[deactivate hide])
  end

  def hide_out_of_stock?
    out_of_stock_strategy == 'hide'
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
      display_contact_address.present? ||
      has_social_links?
  end

  def has_social_links?
    instagram_url.present? || facebook_url.present? || linkedin_url.present?
  end

  def effective_storefront_title
    storefront_title.presence || name
  end

  def effective_sender_name
    email_sender_name.presence || name
  end

  def email_from_address
    "#{effective_sender_name} <no-reply@nodal-seiri.dev>"
  end

  def email_reply_to_address
    email_reply_to.presence
  end

  # Delivery scheduling helpers

  def delivery_day_flags
    @delivery_day_flags || delivery_wdays.map(&:to_s)
  end

  def delivers_on?(wday)
    delivery_days & (1 << wday) != 0
  end

  def delivery_wdays
    (0..6).select { |d| delivers_on?(d) }
  end

  def valid_delivery_day?(date)
    delivers_on?(date.wday)
  end

  def past_cutoff?(time = Time.current)
    return false if order_cutoff_time.blank?

    local_time = time.in_time_zone(timezone)
    hours, minutes = order_cutoff_time.split(":").map(&:to_i)
    cutoff = local_time.change(hour: hours, min: minutes)
    local_time >= cutoff
  end

  def earliest_delivery_date(from: Time.current)
    date = from.in_time_zone(timezone).to_date
    date += 1.day if past_cutoff?(from)

    remaining = lead_time_days
    while remaining > 0
      date += 1.day
      remaining -= 1 if delivers_on?(date.wday)
    end

    date += 1.day until delivers_on?(date.wday)
    date
  end

  private

  def normalize_cutoff_time
    return if order_cutoff_time.blank?

    self.order_cutoff_time = order_cutoff_time.strip[0, 5]
  end

  def set_delivery_days_from_flags
    return unless @delivery_day_flags.is_a?(Array)

    flags = @delivery_day_flags.reject(&:blank?).map(&:to_i)
    self.delivery_days = flags.sum { |d| 1 << d }
  end
end
