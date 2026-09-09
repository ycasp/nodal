class Organisation < ApplicationRecord
  include Slugable

  SUPPORTED_CURRENCIES = %w[EUR CHF USD GBP].freeze
  OUT_OF_STOCK_STRATEGIES = %w[do_nothing deactivate hide].freeze
  CART_STOCK_POLICIES = %w[allow warn remove].freeze
  CART_QTY_OVERFLOW_POLICIES = %w[allow warn cap].freeze
  CHECKOUT_STOCK_POLICIES = %w[allow warn block].freeze
  CART_PRICE_CHANGE_POLICIES = %w[silent notify confirm].freeze
  SHIPPING_MODES = %w[fixed calculated_on_dispatch].freeze
  HEX_COLOR_REGEX = /\A#[0-9A-Fa-f]{6}\z/
  CUTOFF_TIME_REGEX = /\A([01]\d|2[0-3]):[0-5]\d\z/
  CUSTOM_DOMAIN_REGEX = /\A(?:[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?\.)+[a-z]{2,}\z/
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
  has_many :customer_users, dependent: :destroy
  has_many :customer_categories, dependent: :destroy
  has_one :billing_address, -> { billing }, class_name: "Address", as: :addressable, dependent: :destroy
  has_one :contact_address, -> { contact }, class_name: "Address", as: :addressable, dependent: :destroy

  accepts_nested_attributes_for :contact_address, allow_destroy: true, reject_if: :all_blank
  has_many :categories, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :product_attributes, dependent: :destroy
  has_many :product_variants, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :unmet_demands, dependent: :destroy
  has_many :stock_events, dependent: :destroy
  has_many :automations, dependent: :destroy
  has_many :unmet_demand_occurrences, dependent: :destroy
  has_many :customer_product_discounts, dependent: :destroy
  has_many :product_discounts, dependent: :destroy
  has_many :customer_discounts, dependent: :destroy
  has_many :order_discounts, dependent: :destroy
  has_many :promo_codes, dependent: :destroy
  has_one :erp_configuration, dependent: :destroy
  has_many :erp_sync_logs, dependent: :destroy
  has_many :background_tasks, dependent: :destroy
  has_many :email_logs, dependent: :destroy
  has_many :discount_email_notifications, dependent: :destroy
  has_many :homepage_banners, dependent: :destroy
  has_many :homepage_featured_products, dependent: :destroy
  has_many :homepage_featured_categories, dependent: :destroy
  has_many :homepage_special_price_products, dependent: :destroy

  validates :name, presence: true
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :currency, presence: true, inclusion: { in: SUPPORTED_CURRENCIES }
  validates :default_locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validates :out_of_stock_strategy, inclusion: { in: OUT_OF_STOCK_STRATEGIES }
  validates :cart_stock_policy, inclusion: { in: CART_STOCK_POLICIES }
  validates :shipping_mode, inclusion: { in: SHIPPING_MODES }
  validates :cart_qty_overflow_policy, inclusion: { in: CART_QTY_OVERFLOW_POLICIES }
  validates :checkout_stock_policy, inclusion: { in: CHECKOUT_STOCK_POLICIES }
  validates :cart_price_change_policy, inclusion: { in: CART_PRICE_CHANGE_POLICIES }
  validates :max_discount_percentage, numericality: { greater_than: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :primary_color, format: { with: HEX_COLOR_REGEX }, allow_blank: true
  validates :secondary_color, format: { with: HEX_COLOR_REGEX }, allow_blank: true
  validates :campaign_color, format: { with: HEX_COLOR_REGEX }, allow_blank: true
  validates :sale_badge_color, format: { with: HEX_COLOR_REGEX }, allow_blank: true
  validates :email_reply_to, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :lead_time_days, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :low_stock_threshold, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :delivery_days, numericality: { greater_than: 0, only_integer: true }
  validates :order_cutoff_time, format: { with: CUTOFF_TIME_REGEX }, allow_blank: true
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone::MAPPING.values.uniq }
  validates :default_product_sort, inclusion: { in: Product::SORT_OPTIONS }
  validates :custom_domain,
            format: { with: CUSTOM_DOMAIN_REGEX, message: :invalid_hostname },
            uniqueness: { case_sensitive: false },
            allow_blank: true

  before_validation :set_delivery_days_from_flags
  before_validation :normalize_cutoff_time
  before_validation :normalize_custom_domain
  before_save :reset_custom_domain_verification_on_change

  attr_accessor :delivery_day_flags

  slugify :name

  def self.find_by_host(host)
    normalized = host.to_s.strip.downcase.presence
    return nil if normalized.nil?

    find_by(custom_domain: normalized)
  end

  def custom_domain_verified?
    custom_domain.present? && custom_domain_verified_at.present?
  end

  # The host this organisation wants its links to point at. Used by mailers
  # and any background context where there's no request to inspect — returns
  # the verified custom_domain when set, falls back to the canonical host
  # otherwise.
  def preferred_host
    return custom_domain if custom_domain_verified?

    Rails.application.config.x.canonical_host
  end

  # Builds the canonical URL for this organisation given the current
  # request. When the org has a verified custom_domain, strips the leading
  # /:slug from the path so the URL lives at the org's host as the slug-less
  # shape (which is what the dispatcher and routes emit elsewhere). For
  # unverified orgs the path is left as-is and the canonical host is used.
  def canonical_url_for_request(request)
    scheme = request.ssl? ? "https" : request.scheme
    path = request.fullpath

    if custom_domain_verified?
      path = path.sub(%r{\A/#{Regexp.escape(slug)}(?=/|\z)}, "")
      path = "/" if path.empty?
    end

    "#{scheme}://#{preferred_host}#{path}"
  end

  def currency_symbol
    Money::Currency.new(currency).symbol
  end

  def deactivate_out_of_stock?
    out_of_stock_strategy.in?(%w[deactivate hide])
  end

  def hide_out_of_stock?
    out_of_stock_strategy == 'hide'
  end

  # When true the organisation does not charge a flat rate at checkout: the
  # real shipping cost is only known once the order is packed, so it is left
  # out of the customer's total and filled in from the back office later.
  def shipping_calculated_on_dispatch?
    shipping_mode == "calculated_on_dispatch"
  end

  def free_shipping_enabled?
    free_shipping_threshold_cents.present? && free_shipping_threshold_cents > 0
  end

  def max_discount_enabled?
    max_discount_percentage.present? && max_discount_percentage > 0
  end

  def effective_primary_color
    primary_color.presence || '#008060'
  end

  def effective_secondary_color
    secondary_color.presence || '#004c3f'
  end

  # Accent colour for the storefront "Campanhas" entry; red by default.
  def effective_campaign_color
    campaign_color.presence || '#dc3545'
  end

  # Background colour for the storefront promotion ("PROMOÇÃO/SALE") badge; red
  # by default. Independent of campaign_color so the badge and the "Campanhas"
  # accent can be coloured separately.
  def effective_sale_badge_color
    sale_badge_color.presence || '#dc3545'
  end

  def display_contact_address
    if use_billing_address_for_contact?
      billing_address
    else
      contact_address
    end
  end

  # Does the org have at least one active campaign discount? Gates the
  # storefront "Promoções" discovery entry. Memoized per instance (the same
  # current_organisation renders the navbar + sidebar on every page).
  def has_active_promotions?
    return @has_active_promotions if defined?(@has_active_promotions)
    @has_active_promotions = product_discounts.active.exists?
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

  # Sender address for outgoing emails. We deliberately keep the bare-host
  # part on the canonical domain even for orgs with verified custom_domains
  # (sending from no-reply@cliente.pt would force the customer to set up
  # DKIM/SPF for us — friction we want to avoid). Links inside the email
  # body still respect preferred_host. Same pattern as Shopify.
  #
  # The sender uses the APEX domain (no www.), not the canonical_host the
  # rest of the app uses for URLs. Resend (and most providers) authorize an
  # apex; sending as no-reply@www.<apex> is rejected with 550. Allow override
  # via MAIL_SENDER_DOMAIN env var for environments where this rule differs.
  def email_from_address
    domain = Rails.application.config.x.mail_sender_domain
    domain ||= Rails.application.config.x.canonical_host.to_s.sub(/\Awww\./, "")
    "#{effective_sender_name} <no-reply@#{domain}>"
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

  def normalize_custom_domain
    return if custom_domain.nil?

    self.custom_domain = custom_domain
      .to_s
      .strip
      .downcase
      .sub(%r{\Ahttps?://}, "")
      .sub(%r{/.*\z}, "")
      .sub(/\.+\z/, "")
      .presence
  end

  # Any change to custom_domain invalidates the previous verification — the
  # new host has to be re-confirmed at the DNS layer. Skip when the caller is
  # already setting verified_at in the same save (e.g. operator marking the
  # pilot as verified after a manual DNS check).
  def reset_custom_domain_verification_on_change
    return unless custom_domain_changed?
    return if custom_domain_verified_at_changed?

    self.custom_domain_verified_at = nil
  end

  def set_delivery_days_from_flags
    return unless @delivery_day_flags.is_a?(Array)

    flags = @delivery_day_flags.reject(&:blank?).map(&:to_i)
    self.delivery_days = flags.sum { |d| 1 << d }
  end
end
