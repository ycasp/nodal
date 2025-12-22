class Organisation < ApplicationRecord
  include Slugable

  SUPPORTED_CURRENCIES = %w[EUR CHF USD GBP].freeze

  monetize :shipping_cost_cents

  has_many :org_members, dependent: :destroy
  has_many :members, through: :org_members, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_one :billing_address, -> { billing }, class_name: "Address", as: :addressable, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :customer_product_discounts, dependent: :destroy
  has_many :product_discounts, dependent: :destroy
  has_many :customer_discounts, dependent: :destroy
  has_many :order_discounts, dependent: :destroy

  validates :name, presence: true
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :currency, presence: true, inclusion: { in: SUPPORTED_CURRENCIES }

  slugify :name

  def currency_symbol
    Money::Currency.new(currency).symbol
  end
end
