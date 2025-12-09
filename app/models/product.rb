class Product < ApplicationRecord
  belongs_to :organisation
  belongs_to :category
  has_many :order_items, dependent: :restrict_with_error
  has_many :orders, through: :order_items
  has_many :customer_product_discounts, dependent: :destroy

  has_one_attached :photo

  validates :slug, uniqueness: true
  validates :name, presence: true
  validates :description, length: { minimum: 5, maximum: 150 }
  monetize :unit_price, as: :price

  def active_discount_for(customer)
    return nil unless customer
    customer_product_discounts.active.find_by(customer: customer)
  end

  def discounted_price_for(discount)
    return price unless discount
    price - (price * discount.discount_percentage)
  end
end
