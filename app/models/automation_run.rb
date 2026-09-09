# One firing of an Automation. Without this, "I didn't get Friday's email" is
# undebuggable — a skipped run and a failed one look identical from outside.
class AutomationRun < ApplicationRecord
  RUNNING   = "running".freeze
  COMPLETED = "completed".freeze
  SKIPPED   = "skipped".freeze
  FAILED    = "failed".freeze
  STATUSES  = [ RUNNING, COMPLETED, SKIPPED, FAILED ].freeze

  # Why a run produced no email. "Skipped" on its own sends the reader to the
  # console to find out; these say it on the page.
  SKIP_EMPTY          = "empty".freeze
  SKIP_NO_RECIPIENTS  = "no_recipients".freeze

  belongs_to :automation
  belongs_to :organisation

  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :failed, -> { where(status: FAILED) }

  def duration
    return nil unless started_at

    (completed_at || Time.current) - started_at
  end
end
