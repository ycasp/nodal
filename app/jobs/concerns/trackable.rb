module Trackable
  extend ActiveSupport::Concern

  # Raised when the back office cancelled the task while its job was working.
  # Not a failure: the job stopped because it was asked to.
  class Cancelled < StandardError; end

  included do
    after_perform :mark_completed

    rescue_from(StandardError) do |exception|
      if @background_task
        @background_task.update!(
          status: :failed,
          error_message: exception.message,
          completed_at: Time.current
        )
      end
      raise exception
    end

    # Declared after the StandardError handler so it wins: Rescuable matches
    # handlers in reverse order of declaration. The task already says
    # `cancelled` — all that is left is to close it, and not re-raise, because
    # stopping on request is not a job failure.
    rescue_from(Cancelled) do
      @background_task&.update!(completed_at: Time.current)
    end
  end

  private

  # Marking the task running belongs here, not in a before_perform callback:
  # the callback fires before `perform` runs, and every job only looks its task
  # up on the first line of `perform`, so @background_task was still nil and the
  # marking silently did nothing. Tasks stayed `pending` for their whole run and
  # `started_at` was never written — which also left a job killed mid-flight
  # (OOM, SIGKILL: no exception to rescue) indistinguishable from one that never
  # started.
  def find_task(task_id)
    @background_task = BackgroundTask.find(task_id)
    checkpoint!
    mark_running
    @background_task
  end

  # Cancelling cannot kill a job from the outside — the back office only writes
  # `cancelled` on the row — so the job has to notice for itself. A checkpoint
  # is a place where it can still stop cleanly: here at the start (so a task
  # cancelled while it was still queued never does the work at all) and at every
  # progress report. A job that reports no progress can only be stopped before
  # it starts.
  def checkpoint!
    return unless @background_task
    return unless BackgroundTask.where(id: @background_task.id).pick(:status) == "cancelled"

    raise Cancelled
  end

  def mark_running
    return unless @background_task
    @background_task.update!(status: :running, started_at: Time.current)
  end

  def mark_completed
    return unless @background_task
    @background_task.update!(status: :completed, completed_at: Time.current)
  end

  def update_progress(progress, total = nil)
    return unless @background_task
    attrs = { progress: progress }
    attrs[:total] = total if total
    @background_task.update_columns(attrs)
    checkpoint!
  end

  def save_result(result)
    return unless @background_task
    @background_task.update_columns(result: result)
  end
end
