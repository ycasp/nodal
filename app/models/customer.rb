class Customer < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # Note: :registerable is excluded - Members create customer accounts
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  belongs_to :organisation
  has_many :orders, dependent: :destroy

  validates :company_name, presence: true
  validates :contact_name, presence: true
  validates :active, inclusion: { in: [true, false] }

end
