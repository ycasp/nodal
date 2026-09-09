class CreateBackgroundTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :background_tasks do |t|
      t.references :organisation, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.string :task_type
      t.string :status
      t.integer :progress
      t.integer :total
      t.jsonb :result
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
    add_index :background_tasks, :status
  end
end
