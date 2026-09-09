class AutomationRunJob < ApplicationJob
  queue_as :default

  def perform(automation_id, manual: false)
    automation = Automation.find_by(id: automation_id)
    return if automation.nil?
    return unless automation.active? || manual

    Automations::Runner.new(automation).call(manual: manual)
  end
end
