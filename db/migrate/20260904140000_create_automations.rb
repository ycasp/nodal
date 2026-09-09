class CreateAutomations < ActiveRecord::Migration[7.1]
  def change
    create_table :automations do |t|
      t.references :organisation, null: false, foreign_key: true

      t.string :name, null: false
      # Key into Automations::Registry — decides which report is run.
      t.string :kind, null: false
      t.boolean :active, null: false, default: true

      # daily | weekly | monthly. schedule_day is the wday (0-6, Sunday=0) for
      # weekly and the day of month (1-28) for monthly; unused for daily.
      t.string :schedule_kind, null: false, default: "weekly"
      t.integer :schedule_day
      t.integer :schedule_hour, null: false, default: 9

      # Report-specific narrowing (supplier, category_ids, ...). The shape is
      # declared by the report class, not by this table.
      t.jsonb :filters, null: false, default: {}
      # { "org_member_ids" => [...], "external_emails" => [...] } — kept apart
      # because external recipients can't be sent links into the BO.
      t.jsonb :recipients, null: false, default: {}

      t.boolean :skip_if_empty, null: false, default: true

      t.datetime :last_run_at
      t.datetime :next_run_at

      t.timestamps
    end

    add_index :automations, [ :organisation_id, :active ]
    # The dispatcher's only query: "which automations are due?"
    add_index :automations, :next_run_at

    create_table :automation_runs do |t|
      t.references :automation, null: false, foreign_key: true
      t.references :organisation, null: false, foreign_key: true

      # running | completed | skipped | failed
      t.string :status, null: false, default: "running"
      t.boolean :manual, null: false, default: false

      t.datetime :started_at
      t.datetime :completed_at
      # The window the report covered, so a run is reproducible after the fact.
      t.datetime :period_start
      t.datetime :period_end

      t.integer :rows_count, null: false, default: 0
      t.integer :recipients_count, null: false, default: 0
      t.text :error_message

      t.timestamps
    end

    add_index :automation_runs, [ :automation_id, :created_at ]
  end
end
