class AddTextThemeToHomepageBanners < ActiveRecord::Migration[7.1]
  def change
    add_column :homepage_banners, :text_theme, :string, default: 'light', null: false
  end
end
