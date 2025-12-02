class Product < ApplicationRecord
  belongs_to :organisation
  belongs_to :category

  has_one_attached :photo

  validates :slug, uniqueness: true
  validates :name, presence: true
  validates :description, length: { minimum: 5, maximum: 150 }
end
