class AddNotesToShoppingLists < ActiveRecord::Migration[7.1]
  def change
    add_column :shopping_lists, :notes, :text
  end
end
