class CreateUnmetDemandOccurrences < ActiveRecord::Migration[7.1]
  # Append-only log: one row each time a cart stock policy cuts a line. Never
  # overwritten, so the history survives across episodes (e.g. an article that
  # was capped, later removed, later resolved, then short again). Keys are
  # denormalised (login/customer/product/variant) so the BO can group the full
  # history of an article+login even after the open aggregate row has closed.
  def change
    create_table :unmet_demand_occurrences do |t|
      t.references :unmet_demand,    null: true,  foreign_key: { on_delete: :nullify }
      t.references :organisation,    null: false, foreign_key: true
      t.references :customer,        null: false, foreign_key: true
      t.references :customer_user,   null: false, foreign_key: true
      t.references :product,         null: false, foreign_key: true
      t.references :product_variant, null: true,  foreign_key: true

      t.integer :requested_quantity, null: false   # what they asked for
      t.integer :kept_quantity,      null: false, default: 0 # what stock left them (capped-to, or 0)
      t.string  :reason,             null: false   # capped | removed
      t.datetime :occurred_at,       null: false

      t.timestamps
    end

    add_index :unmet_demand_occurrences,
              [:customer_user_id, :product_id, :product_variant_id],
              name: "index_unmet_demand_occurrences_on_login_product_variant"
  end
end
