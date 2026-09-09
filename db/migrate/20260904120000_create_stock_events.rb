class CreateStockEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :stock_events do |t|
      t.references :organisation, null: false, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true

      # out_of_stock | back_in_stock | low_stock
      t.string :kind, null: false
      t.integer :from_quantity
      t.integer :to_quantity
      t.datetime :occurred_at, null: false
      # Where the transition came from: "app" (sync, BO edit, imports) or
      # "erp_sync_log" (rows reconstructed by the backfill rake task).
      t.string :source, null: false, default: "app"

      t.timestamps
    end

    # The digest query: "events of kind X, for this org, in this period".
    add_index :stock_events, [ :organisation_id, :kind, :occurred_at ]
    # The per-variant history view.
    add_index :stock_events, [ :product_variant_id, :occurred_at ]
  end
end
