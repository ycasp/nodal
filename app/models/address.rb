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
  scope :manual,   -> { where(external_source: nil) }
  scope :from_erp, -> { where.not(external_source: nil) }

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

  # Stable fingerprint used by sync to detect whether an incoming ERP
  # address matches one we already have. Normalized so small formatting
  # differences (extra spaces, casing) don't create duplicates.
  def fingerprint
    self.class.fingerprint_for(
      street_name: street_name,
      street_nr: street_nr,
      postal_code: postal_code,
      city: city,
      country: country
    )
  end

  def self.fingerprint_for(street_name:, street_nr:, postal_code:, city:, country:)
    [street_name, street_nr, postal_code, city, country]
      .map { |v| v.to_s.strip.downcase.squeeze(" ") }
      .join("|")
  end
end
