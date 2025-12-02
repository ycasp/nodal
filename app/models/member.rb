class Member < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :org_members, dependent: :destroy
  has_many :organisations, through: :org_members

  validates :first_name, :last_name, presence: true
end
