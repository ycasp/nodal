class CreateAddresses < ActiveRecord::Migration[7.1]
  def change
    create_table :addresses do |t|
      t.string :street_name
      t.string :street_nr
      t.string :postal_code
      t.string :city
      t.string :country
      t.string :address_type
      t.references :addressable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
