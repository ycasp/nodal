class CreateCustomerAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_assignments do |t|
      t.references :org_member, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true, index: { unique: true }
      t.datetime :assigned_at, null: false

      t.timestamps
    end
  end
end
