class AddShowScrollToTopToOrganisations < ActiveRecord::Migration[7.1]
  def change
    add_column :organisations, :show_scroll_to_top, :boolean, default: true, null: false
  end
end
