class Customer < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # Note: :registerable is excluded - Members create customer accounts
  # Note: :validatable is excluded - email uniqueness is scoped to organisation
  devise :database_authenticatable,
         :recoverable, :rememberable, :invitable,
         authentication_keys: [:email, :organisation_id]

  def devise_mailer
    CustomerMailer
  end

  belongs_to :organisation
  has_many :orders, dependent: :destroy
  has_one :billing_address, -> { billing }, class_name: "Address", as: :addressable, dependent: :destroy
  has_many :shipping_addresses, -> { shipping }, class_name: "Address", as: :addressable, dependent: :destroy
  has_many :customer_product_discounts, dependent: :destroy
  has_many :customer_discounts, dependent: :destroy

  validates :company_name, presence: true
  validates :contact_name, presence: true
  validates :active, inclusion: { in: [true, false] }

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

  def self.find_for_database_authentication(warden_conditions)
     raise
     org = Organisation.find_by(slug: params[:org_slug])
     where(organisation: org, email: warden_conditions[:email]).first
  end

  def current_cart(organisation)
    orders.draft.find_or_create_by!(organisation: organisation)
  end

  def active_discounts_for_products(product_ids)
    customer_product_discounts
      .active
      .where(product_id: product_ids)
      .index_by(&:product_id)
  end

  def active_customer_discount
    customer_discounts.active.first
  end

  def has_active_global_discount?
    active_customer_discount.present?
  end

  private

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end

  def email_required?
    true
  end
end
