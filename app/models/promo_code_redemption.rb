class PromoCodeRedemption < ApplicationRecord
  belongs_to :promo_code
  belongs_to :customer
  belongs_to :order

  monetize :discount_amount_cents

  validates :order_id, uniqueness: true
end
