class AddSkipReasonToAutomationRuns < ActiveRecord::Migration[7.1]
  def change
    add_column :automation_runs, :skip_reason, :string
  end
end
