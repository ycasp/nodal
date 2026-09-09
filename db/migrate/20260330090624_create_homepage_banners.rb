class CreateHomepageBanners < ActiveRecord::Migration[7.1]
  def change
    create_table :homepage_banners do |t|
      t.references :organisation, null: false, foreign_key: true
      t.string :title
      t.string :subtitle
      t.string :link_url
      t.string :link_text
      t.integer :position
      t.boolean :active, default: true, null: false

      t.timestamps
    end
  end
end
