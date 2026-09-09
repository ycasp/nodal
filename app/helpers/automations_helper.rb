module AutomationsHelper
  def automation_schedule_summary(automation)
    hour = automation.schedule_time

    case automation.schedule_kind
    when "daily"
      t("bo.automations.summary.daily", hour: hour)
    when "weekly"
      t("bo.automations.summary.weekly",
        day: t("date.day_names")[automation.schedule_day.to_i],
        hour: hour)
    when "monthly"
      t("bo.automations.summary.monthly", day: automation.schedule_day, hour: hour)
    end
  end
end
