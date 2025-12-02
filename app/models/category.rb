class Category < ApplicationRecord
  belongs_to :organisation
  has_many :products

  validates :name, presence: :true
  validates :name, uniqueness: { case_sensitive: false, scope: :organisation,
    message: "Category #{:name} already exists"}

  before_save :ensure_layout

  private

  def ensure_layout
    name.downcase!
    name.capitalize!
  end
end
