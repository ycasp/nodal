class CreateQuickAccessPhase1 < ActiveRecord::Migration[7.1]
  def change
    create_table :quick_access_tokens do |t|
      t.references :customer_user, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.references :created_by_member, foreign_key: { to_table: :members }
      t.timestamps
    end
    add_index :quick_access_tokens, :token, unique: true
    add_index :quick_access_tokens, [:customer_user_id, :revoked_at]

    create_table :customer_user_login_events do |t|
      t.references :customer_user, foreign_key: true # nullable for unknown-user failures
      t.references :organisation, null: false, foreign_key: true
      t.string :method, null: false
      t.boolean :success, null: false
      t.string :ip_address
      t.string :user_agent
      t.string :failure_reason
      t.timestamps
    end
    add_index :customer_user_login_events, [:customer_user_id, :created_at]
    add_index :customer_user_login_events, [:organisation_id, :created_at]

    add_column :organisations, :quick_access_token_ttl_days, :integer, default: 90, null: false
  end
end
