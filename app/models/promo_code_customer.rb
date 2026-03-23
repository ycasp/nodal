class PromoCodeCustomer < ApplicationRecord
  belongs_to :promo_code
  belongs_to :customer

  validates :customer_id, uniqueness: { scope: :promo_code_id }
end
