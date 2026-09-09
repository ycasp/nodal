class CreateCustomerUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :customer_users do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :organisation, null: false, foreign_key: true

      # Devise database_authenticatable
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      # Devise recoverable
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      # Devise rememberable
      t.datetime :remember_created_at

      # Devise invitable
      t.string :invitation_token
      t.datetime :invitation_created_at
      t.datetime :invitation_sent_at
      t.datetime :invitation_accepted_at
      t.integer :invitation_limit
      t.string :invited_by_type
      t.bigint :invited_by_id
      t.integer :invitations_count, default: 0

      # Devise trackable
      t.integer :sign_in_count, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip

      # Personal (per-login)
      t.string :contact_name
      t.string :contact_phone
      t.string :locale
      t.boolean :email_notifications_enabled, default: true, null: false
      t.boolean :hide_prices, default: false, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :customer_users, [:email, :organisation_id], unique: true
    add_index :customer_users, :invitation_token, unique: true
    add_index :customer_users, :reset_password_token, unique: true
    add_index :customer_users, :invited_by_id
    add_index :customer_users, [:invited_by_type, :invited_by_id]
    add_index :customer_users, :locale
  end
end
