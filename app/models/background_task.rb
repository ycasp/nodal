class BackgroundTask < ApplicationRecord
  belongs_to :organisation
  belongs_to :member

  has_one_attached :file

  enum :status, {
    pending: "pending",
    running: "running",
    completed: "completed",
    failed: "failed",
    cancelled: "cancelled"
  }, default: :pending

  scope :recent, -> { order(created_at: :desc) }

  def progress_percentage
    return 0 if total.nil? || total.zero?
    [(progress.to_f / total * 100).round, 100].min
  end

  def duration
    return nil unless started_at
    (completed_at || Time.current) - started_at
  end
end
