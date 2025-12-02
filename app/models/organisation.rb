class Organisation < ApplicationRecord
  has_many :org_members, dependent: :destroy
  has_many :members, through: :org_members
  has_many :customers, dependent: :destroy
  has_many :addresses, as: :addressable, dependent: :destroy
  has_one :billing_address, -> { billing }, class_name: "Address", as: :addressable, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only lowercase letters, numbers, and hyphens" }
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
end
