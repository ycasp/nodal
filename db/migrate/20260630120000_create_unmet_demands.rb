class CreateUnmetDemands < ActiveRecord::Migration[7.1]
  def change
    create_table :unmet_demands do |t|
      t.references :organisation,    null: false, foreign_key: true
      t.references :customer,        null: false, foreign_key: true
      # The login (cart owner) that actually hit the shortfall — actions target
      # THIS user's cart, and the BO contacts this specific person.
      t.references :customer_user,   null: false, foreign_key: true
      t.references :product,         null: false, foreign_key: true
      t.references :product_variant, null: true,  foreign_key: true
      # The draft order generated when a Member chooses to satisfy the demand.
      # Nullify the link if that order is later deleted — keep the resolved
      # demand record rather than blocking the delete.
      t.references :order,           null: true,  foreign_key: { on_delete: :nullify }
      # When the demand is resolved by offering a different product ("Trocar").
      t.bigint :substitute_product_id
      t.bigint :resolved_by_member_id

      t.integer :requested_quantity, null: false
      t.integer :fulfilled_quantity, null: false, default: 0
      t.string  :reason,     null: false            # capped | removed
      t.string  :status,     null: false, default: "open" # open | resolved | dismissed
      t.string  :resolution                          # customer_self_served | draft_generated | dismissed

      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at,  null: false
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :unmet_demands, [:organisation_id, :status]
    add_index :unmet_demands, [:customer_id, :status]
    add_index :unmet_demands, :substitute_product_id
    add_foreign_key :unmet_demands, :products, column: :substitute_product_id, on_delete: :nullify

    # One open row per LOGIN + product + variant (the shortfall belongs to a
    # specific cart). NULLs are distinct in a plain unique index, so COALESCE
    # the (nullable) variant to 0 to dedupe variant-less removals too. The
    # recorder also find_or_initializes, but this guards concurrent refreshes.
    add_index :unmet_demands,
              "customer_user_id, product_id, COALESCE(product_variant_id, 0)",
              unique: true,
              where: "status = 'open'",
              name: "index_unmet_demands_open_uniqueness"
  end
end
