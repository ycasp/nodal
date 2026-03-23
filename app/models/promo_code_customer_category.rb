class PromoCodeCustomerCategory < ApplicationRecord
  belongs_to :promo_code
  belongs_to :customer_category

  validates :customer_category_id, uniqueness: { scope: :promo_code_id }
end
