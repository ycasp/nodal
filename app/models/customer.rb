class Customer < ApplicationRecord
  include ErpSyncable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # Note: :registerable is excluded - Members create customer accounts
  # Note: :validatable is excluded - email uniqueness is scoped to organisation
  devise :database_authenticatable,
         :recoverable, :rememberable, :invitable, :trackable,
         authentication_keys: [:email, :organisation_id]

  def devise_mailer
    CustomerMailer
  end

  belongs_to :organisation
  belongs_to :customer_category, optional: true
  has_many :orders, dependent: :destroy
  has_one :billing_address, -> { billing.active }, class_name: "Address", as: :addressable, dependent: :destroy
  has_many :shipping_addresses, -> { shipping.active }, class_name: "Address", as: :addressable, dependent: :destroy
  has_one :billing_address_with_archived, -> { billing }, class_name: "Address", as: :addressable, dependent: :destroy
  has_many :shipping_addresses_with_archived, -> { shipping }, class_name: "Address", as: :addressable, dependent: :destroy
  has_many :shopping_lists, dependent: :destroy
  has_many :customer_product_discounts, dependent: :destroy
  has_many :customer_discounts, dependent: :destroy
  has_many :promo_code_customers, dependent: :destroy
  has_many :promo_codes, through: :promo_code_customers
  has_many :promo_code_redemptions, dependent: :destroy

  validates :company_name, presence: true
  validates :contact_name, presence: true
  validates :active, inclusion: { in: [true, false] }
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }, allow_nil: true

  # Email validations (from Devise::Models::Validatable, with scoped uniqueness)
  validates :email, presence: true, if: :email_required?
  validates :email, uniqueness: { scope: :organisation_id, case_sensitive: true, allow_blank: true },
                    if: :will_save_change_to_email?
  validates :email, format: {with: Devise.email_regexp, allow_blank: true },
                    if: :will_save_change_to_email?

  # Password validations (from Devise::Models::Validatable)
  validates :password, presence: true, if: :password_required?
  validates :password, confirmation: true, if: :password_required?
  validates :password, length: { within: Devise.password_length, allow_blank: true }

  # Addresses validation (PEDRO)
  #accepts_nested_attributes_for :billing_address, update_only: true
  #accepts_nested_attributes_for :shipping_addresses
  #new below
  accepts_nested_attributes_for :billing_address_with_archived, update_only: true, reject_if: :address_blank?
  accepts_nested_attributes_for :shipping_addresses_with_archived, reject_if: :address_blank?


  def self.find_for_database_authentication(warden_conditions)
     raise
     org = Organisation.find_by(slug: params[:org_slug])
     where(organisation: org, email: warden_conditions[:email]).first
  end

  def current_cart(organisation)
    orders.draft.find_or_create_by!(organisation: organisation)
  end

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

  def invitation_status
    if !active?
      :inactive
    elsif invitation_accepted_at.present?
      :active
    elsif invitation_sent_at.present?
      :pending
    else
      :not_invited
    end
  end

  private

  def address_blank?(attributes)
    attributes.except('id', 'address_type', 'active', '_destroy').values.all?(&:blank?)
  end

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end

  def email_required?
    true
  end
end
