class AddNoteToOrderItems < ActiveRecord::Migration[7.1]
  def change
    add_column :order_items, :note, :text
  end
end
