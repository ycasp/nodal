class AddViewedAtToBackgroundTasks < ActiveRecord::Migration[7.1]
  def change
    add_column :background_tasks, :viewed_at, :datetime
  end
end
