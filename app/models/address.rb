class Address < ApplicationRecord
  belongs_to :addressable, polymorphic: true

  TYPES = %w[billing shipping].freeze

  validates :street_name, presence: true
  validates :postal_code, presence: true
  validates :city, presence: true
  validates :country, presence: true
  validates :address_type, presence: true, inclusion: { in: TYPES }

  scope :billing, -> { where(address_type: "billing") }
  scope :shipping, -> { where(address_type: "shipping") }

  def billing?
    address_type == "billing"
  end

  def shipping?
    address_type == "shipping"
  end
end
