# Runs every 15 minutes (config/recurring.yml) and fires whatever is due.
#
# Automations are created by users at runtime, so they can't live in
# recurring.yml — that file is static and resolved at deploy time. One fixed
# entry dispatching to per-automation jobs is the same shape as
# ErpScheduledSyncJob.
class AutomationDispatchJob < ApplicationJob
  queue_as :default

  def perform
    Automation.due.find_each do |automation|
      AutomationRunJob.perform_later(automation.id)
    end
  end
end
