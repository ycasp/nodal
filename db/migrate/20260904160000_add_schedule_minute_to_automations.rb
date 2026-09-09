class AddScheduleMinuteToAutomations < ActiveRecord::Migration[7.1]
  def change
    add_column :automations, :schedule_minute, :integer, null: false, default: 0
  end
end
