class CreateDiscountEmailNotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :discount_email_notifications do |t|
      t.references :notifiable, polymorphic: true, null: false
      t.references :organisation, null: false, foreign_key: true
      t.string :status, null: false, default: 'pending'
      t.integer :recipient_count, default: 0
      t.datetime :sent_at
      t.references :sent_by, foreign_key: { to_table: :members }, null: true
      t.timestamps
    end

    add_index :discount_email_notifications, [:notifiable_type, :notifiable_id],
              unique: true, name: 'idx_den_on_notifiable'
    add_index :discount_email_notifications, [:organisation_id, :status]
  end
end
