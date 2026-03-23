class CreateEmailLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :email_logs do |t|
      t.references :organisation, null: false, foreign_key: true
      t.references :customer, null: true, foreign_key: true
      t.references :member, null: true, foreign_key: true
      t.string :email_type, null: false
      t.string :mailer_class, null: false
      t.string :recipient_email, null: false
      t.string :subject
      t.string :status, null: false, default: "sent"
      t.string :error_message
      t.datetime :sent_at

      t.timestamps
    end

    add_index :email_logs, [:organisation_id, :sent_at]
    add_index :email_logs, :status
  end
end
