class AddSupplierToProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :supplier, :string
    add_index :products, [:organisation_id, :supplier]
  end
end
