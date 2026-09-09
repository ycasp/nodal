# A job killed outright — the dyno OOM-killing a catalog render, a deploy cutting
# a worker mid-flight — leaves no exception behind, so Trackable's rescue_from
# never fires and the BackgroundTask it was working on stays open forever.
# Nothing else ever closes it: seven catalog tasks sat at pending in production
# for weeks, still showing a half-finished progress bar.
#
# A false positive is harmless. If the task turns out to be alive after all, its
# job finishes normally and mark_completed writes the real outcome over ours.
class ReapStalledBackgroundTasksJob < ApplicationJob
  queue_as :default

  STALE_AFTER = 2.hours

  def perform
    stalled_tasks.find_each do |task|
      task.update!(
        status: :failed,
        error_message: stalled_message(task),
        completed_at: Time.current
      )
    end
  end

  private

  # `updated_at` is no help here: progress is written with update_columns, which
  # skips timestamps, so a task that worked for an hour looks untouched.
  # started_at is when the work began; created_at covers a task whose job was
  # never picked up at all.
  def stalled_tasks
    BackgroundTask
      .where(status: [ :pending, :running ])
      .where("COALESCE(background_tasks.started_at, background_tasks.created_at) < ?", STALE_AFTER.ago)
  end

  # The message is read in the back office, so write it in the organisation's
  # language rather than the process default.
  def stalled_message(task)
    locale = task.organisation&.default_locale.presence || I18n.default_locale

    I18n.t(
      "bo.background_tasks.stalled",
      hours: (STALE_AFTER / 1.hour).to_i,
      locale: locale
    )
  end
end
