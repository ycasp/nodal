class ShoppingList < ApplicationRecord
  belongs_to :customer
  belongs_to :organisation
  has_many :shopping_list_items, dependent: :destroy

  validates :name, presence: true

  scope :ordered, -> { order(updated_at: :desc) }

  def item_count
    shopping_list_items.sum(:quantity)
  end

  def line_item_count
    shopping_list_items.count
  end
end
