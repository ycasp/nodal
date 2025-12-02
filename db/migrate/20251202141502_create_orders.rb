class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :organisation, null: false, foreign_key: true
      t.string :order_number, null: false
      t.string :status, default: "in_process"
      t.string :payment_status, default: "pending"
      t.datetime :placed_at
      t.date :receive_on
      t.text :notes

      t.timestamps
    end

    add_index :orders, :order_number, unique: true
  end
end
