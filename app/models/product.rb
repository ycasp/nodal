class Product < ApplicationRecord
  belongs_to :organisation
  belongs_to :category
  has_many :order_items, dependent: :restrict_with_error
  has_many :orders, through: :order_items

  has_one_attached :photo

  validates :slug, uniqueness: true
  validates :name, presence: true
  validates :description, length: { minimum: 5, maximum: 150 }
  monetize :unit_price, as: :price
end
