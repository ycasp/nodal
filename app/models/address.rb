class Address < ApplicationRecord
  belongs_to :addressable, polymorphic: true

  TYPES = %w[billing shipping contact].freeze

  validates :street_name, presence: true
  validates :postal_code, presence: true
  validates :city, presence: true
  validates :country, presence: true
  validates :address_type, presence: true, inclusion: { in: TYPES }

  scope :billing, -> { where(address_type: "billing") }
  scope :shipping, -> { where(address_type: "shipping") }
  scope :contact, -> { where(address_type: "contact") }
  scope :active,   -> { where(active: true) }

  def billing?
    address_type == "billing"
  end

  def shipping?
    address_type == "shipping"
  end

  def contact?
    address_type == "contact"
  end

  def full_address
  [
    "#{street_name} #{street_nr}".strip,
    "#{postal_code} #{city}".strip,
    country
  ].compact.reject(&:blank?).join(", ")
  end

  def archived?
    !active
  end

end
