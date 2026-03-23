class CustomerCategory < ApplicationRecord
  belongs_to :organisation
  has_many :customers, dependent: :nullify
  has_many :customer_discounts, dependent: :destroy
  has_many :customer_product_discounts, dependent: :destroy
  has_many :promo_code_customer_categories, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :organisation_id }

  scope :ordered, -> { order(:name) }
end
