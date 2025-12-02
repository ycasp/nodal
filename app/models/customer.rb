class Customer < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # Note: :registerable is excluded - Members create customer accounts
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  belongs_to :organisation
  has_many :addresses, as: :addressable, dependent: :destroy
  has_one :billing_address, -> { billing }, class_name: "Address", as: :addressable, dependent: :destroy
  has_many :shipping_addresses, -> { shipping }, class_name: "Address", as: :addressable, dependent: :destroy

  validates :company_name, presence: true
  validates :contact_name, presence: true
  validates :active, inclusion: { in: [true, false] }
end
