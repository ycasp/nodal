class Customer < ApplicationRecord
  include ErpSyncable
  include HasExportableColumns

  # Auth lives on CustomerUser, not on Customer. Customer is the empresa.
  # Auth-related columns (encrypted_password, reset_password_*, invitation_*,
  # remember_created_at, sign_in tracking) still exist on this table but are
  # orphan after the split — they get dropped in a follow-up migration so
  # rollback of this PR stays trivial.

  belongs_to :organisation
  belongs_to :customer_category, optional: true
  belongs_to :created_by_member, class_name: "OrgMember", optional: true
  # Order matters: orders must be destroyed BEFORE customer_users, otherwise
  # CustomerUser#dependent: :nullify tries to set orders.customer_user_id =
  # NULL on the cascade and hits the NOT NULL constraint added in PR #113.
  has_many :orders, dependent: :destroy
  has_many :customer_users, dependent: :destroy
  has_one :customer_assignment, dependent: :destroy
  has_one :sales_rep, through: :customer_assignment, source: :org_member
  has_one :billing_address, -> { billing.active }, class_name: "Address", as: :addressable, dependent: :destroy
  has_many :shipping_addresses, -> { shipping.active }, class_name: "Address", as: :addressable, dependent: :destroy
  has_one :billing_address_with_archived, -> { billing }, class_name: "Address", as: :addressable, dependent: :destroy
  has_many :shipping_addresses_with_archived, -> { shipping }, class_name: "Address", as: :addressable, dependent: :destroy
  has_many :shopping_lists, dependent: :destroy
  has_many :unmet_demands, dependent: :destroy
  has_many :unmet_demand_occurrences, dependent: :destroy
  has_many :customer_product_discounts, dependent: :destroy
  has_many :customer_discounts, dependent: :destroy
  has_many :promo_code_customers, dependent: :destroy
  has_many :promo_codes, through: :promo_code_customers
  has_many :promo_code_redemptions, dependent: :destroy
  has_many :email_logs, dependent: :nullify

  validates :company_name, presence: true
  validates :contact_name, presence: true
  validates :active, inclusion: { in: [true, false] }
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }, allow_nil: true
  # Only fires when the NIF is being set/changed — protects new prospects
  # against typing an existing NIF without breaking saves on the handful of
  # legacy customers that still share a NIF (PHC-side dup pending cleanup).
  validates :taxpayer_id,
            uniqueness: { scope: :organisation_id, case_sensitive: false },
            allow_blank: true,
            if: :will_save_change_to_taxpayer_id?

  # Customers eligible to receive transactional/marketing emails: active,
  # accepted their invitation, and have notifications enabled. Auth emails
  # (reset password, invitation itself) bypass this — see EmailDeliveryGuard.
  scope :mailable, -> {
    where(active: true, email_notifications_enabled: true).where.not(invitation_accepted_at: nil)
  }

  # Rep-created customers without an ERP id yet. Orders for these are held
  # locally until admin reconciles via PHC (then ERP sync fills in
  # `external_id` and ErpRetryPendingOrdersJob retries the push).
  scope :pending_erp_sync, -> { where(external_id: nil).where.not(created_by_member_id: nil) }

  # Empresas the ERP has no email address for. They are real customers a rep
  # visits and sells to — they just can't be invited to the storefront until
  # someone collects an address. The column is NOT NULL (default ""), so blank
  # is "" in practice; nil is matched defensively.
  scope :without_email, -> { where(email: [nil, ""]) }

  # When a customer transitions from "no ERP id" to "has ERP id" — typically
  # because ERP sync just reconciled a rep-created empresa — kick off the
  # retry job so any orders that were held back (push_status: pending due to
  # OrderPushService skipping on blank external_id) get another shot.
  after_update_commit :retry_pending_orders_after_erp_sync, if: :saved_change_to_external_id?

  # When a Member creates a customer in the BO (rep prospecting, or admin
  # bulk entry), seed a stub CustomerUser so impersonation has a login to
  # hang the cart and order on. Mirrors the ERP-sync `mirror_customer_user_stub`
  # pattern. Only seeds when there's an email worth carrying — an emailless
  # empresa gets its shell on demand the first time a rep impersonates it, so
  # nothing is lost by waiting. ERP-imported customers are handled separately
  # by the sync service.
  after_create :seed_stub_customer_user, if: -> { created_by_member_id.present? && email.present? }

  def retry_pending_orders_after_erp_sync
    previous, current = saved_change_to_external_id
    return unless previous.blank? && current.present?

    ErpRetryPendingOrdersJob.perform_later(id)
  end

  # A stub with a blank email is legitimate: it's a rep-only shell that lets an
  # empresa without an email hold a cart and orders (orders.customer_user_id is
  # NOT NULL). It can never sign in — no email, no password — see
  # CustomerUser#active_for_authentication?.
  def seed_stub_customer_user
    return if customer_users.exists?

    # Savepoint: via the after_create callback this runs inside the Customer's
    # own save transaction, and a database-level failure below would otherwise
    # leave that transaction aborted — the Customer insert would fail with
    # PG::InFailedSqlTransaction instead of the record simply saving without a
    # stub. requires_new keeps the damage inside the savepoint.
    self.class.transaction(requires_new: true) do
      customer_users.create!(
        organisation_id: organisation_id,
        email: email,
        contact_name: contact_name,
        contact_phone: contact_phone,
        active: true
      )
    end
    # Catches database-level failures too (RecordNotUnique on an address another
    # login in the org already holds, NotNullViolation), not just model
    # validations — callers such as Bo::ImpersonationsController rely on this
    # returning instead of 500ing, and fall back to their own message.
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn(
      "[Customer ##{id}] stub CustomerUser creation skipped: #{e.message}"
    )
  end

  def missing_email?
    email.blank?
  end

  def mailable?
    active? && email_notifications_enabled? && invitation_accepted_at.present?
  end

  def self.exportable_columns
    [
      { key: :company_name, label: I18n.t("bo.export.columns.customer.company_name"), default: true,
        value: ->(r) { r.company_name } },
      { key: :contact_name, label: I18n.t("bo.export.columns.customer.contact_name"), default: true,
        value: ->(r) { r.contact_name } },
      { key: :login_emails, label: I18n.t("bo.export.columns.customer.login_emails"), default: true,
        value: ->(r) { r.customer_users.map(&:email).compact_blank.join("; ").presence } },
      # Legacy orphan ERP-mirror field (the real login email lives on
      # CustomerUser → login_emails above); off by default to avoid confusion.
      { key: :email, label: I18n.t("bo.export.columns.customer.email"), default: false,
        value: ->(r) { r.email } },
      { key: :contact_phone, label: I18n.t("bo.export.columns.customer.contact_phone"), default: true,
        value: ->(r) { r.contact_phone } },
      { key: :category, label: I18n.t("bo.export.columns.customer.category"), default: true,
        value: ->(r) { r.customer_category&.name } },
      { key: :taxpayer_id, label: I18n.t("bo.export.columns.customer.taxpayer_id"), default: false,
        value: ->(r) { r.taxpayer_id } },
      { key: :active, label: I18n.t("bo.export.columns.customer.active"), default: true,
        value: ->(r) { r.active? ? I18n.t("bo.common.yes") : I18n.t("bo.common.no") } },
      { key: :invitation_status, label: I18n.t("bo.export.columns.customer.invitation_status"), default: false,
        value: ->(r) { I18n.t("bo.common.statuses.#{r.invitation_status}") } },
      { key: :last_sign_in_at, label: I18n.t("bo.export.columns.customer.last_sign_in_at"), default: false,
        value: ->(r) { r.last_sign_in_at&.strftime("%Y-%m-%d %H:%M") } },
      { key: :created_at, label: I18n.t("bo.export.columns.customer.created_at"), default: false,
        value: ->(r) { I18n.l(r.created_at, format: :short) } },
      { key: :billing_street, label: I18n.t("bo.export.columns.customer.billing_street"), default: false,
        value: ->(r) { r.billing_address&.street_name } },
      { key: :billing_street_nr, label: I18n.t("bo.export.columns.customer.billing_street_nr"), default: false,
        value: ->(r) { r.billing_address&.street_nr } },
      { key: :billing_postal_code, label: I18n.t("bo.export.columns.customer.billing_postal_code"), default: false,
        value: ->(r) { r.billing_address&.postal_code } },
      { key: :billing_city, label: I18n.t("bo.export.columns.customer.billing_city"), default: false,
        value: ->(r) { r.billing_address&.city } },
      { key: :billing_country, label: I18n.t("bo.export.columns.customer.billing_country"), default: false,
        value: ->(r) { r.billing_address&.country } },
      { key: :shipping_addresses, label: I18n.t("bo.export.columns.customer.shipping_addresses"), default: false,
        value: ->(r) {
          r.shipping_addresses.map do |a|
            [a.street_name, a.street_nr, a.postal_code, a.city, a.country].compact_blank.join(", ")
          end.compact_blank.join("; ").presence
        } }
    ]
  end

  # Email column is now an orphan ERP-mirror field (the login email lives
  # on CustomerUser). Format validated only when present.
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true },
                    if: :will_save_change_to_email?

  # Addresses validation (PEDRO)
  #accepts_nested_attributes_for :billing_address, update_only: true
  #accepts_nested_attributes_for :shipping_addresses
  #new below
  accepts_nested_attributes_for :billing_address_with_archived, update_only: true, reject_if: :address_blank?
  accepts_nested_attributes_for :shipping_addresses_with_archived, reject_if: :address_blank?


  def active_discounts_for_products(product_ids)
    # Direct customer discounts take precedence
    direct = customer_product_discounts
      .active
      .where(product_id: product_ids)
      .index_by(&:product_id)

    # Fill in category-based discounts for products not covered by direct
    if customer_category_id.present?
      missing_ids = product_ids - direct.keys
      if missing_ids.any?
        category_based = CustomerProductDiscount
          .where(customer_category_id: customer_category_id)
          .active
          .where(product_id: missing_ids)
          .index_by(&:product_id)
        direct.merge!(category_based)
      end
    end

    direct
  end

  def active_customer_discount
    # Direct customer discount takes precedence
    direct = customer_discounts.active.first
    return direct if direct

    # Fall back to category-based
    if customer_category_id.present?
      CustomerDiscount.where(customer_category_id: customer_category_id).active.first
    end
  end

  def has_active_global_discount?
    active_customer_discount.present?
  end

  # Aggregate status derived from this customer's logins (CustomerUsers).
  # The login itself owns the granular invitation state — this method just
  # rolls it up into a single per-empresa badge for the BO listing/header.
  #   :inactive     — empresa is inactive (Customer.active = false)
  #   :active       — at least one active login has accepted its invite
  #   :pending      — at least one login has been invited but none accepted
  #   :not_invited  — no logins yet, or none have been invited
  def invitation_status
    return :inactive unless active?

    # Uses Enumerable so the BO listing benefits from `includes(:customer_users)`
    # without triggering N+1 queries — querying via where(...) here would
    # ignore the cached association and hit the DB once per row.
    cus = customer_users.load

    # If there are logins and none of them are active, the empresa is
    # functionally locked out of the storefront — surface that as :inactive
    # too, since the per-login granular state already shows in the BO.
    return :inactive if cus.any? && cus.none?(&:active?)

    return :active if cus.any? { |cu| cu.active? && cu.invitation_accepted_at.present? }
    return :pending if cus.any? { |cu| cu.invitation_sent_at.present? && cu.invitation_accepted_at.nil? }

    :not_invited
  end

  private

  def address_blank?(attributes)
    attributes.except('id', 'address_type', 'active', '_destroy').values.all?(&:blank?)
  end
end
