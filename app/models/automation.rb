# A scheduled report the back office sends by email.
#
# The row holds the *configuration* (what, when, to whom); the report itself is
# a class in Automations::Registry, keyed by `kind`. Adding a new automation
# type is a new report class, not a change here.
class Automation < ApplicationRecord
  SCHEDULE_KINDS = %w[daily weekly monthly].freeze

  belongs_to :organisation
  has_many :automation_runs, dependent: :destroy

  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: -> (_) { Automations::Registry.keys } }
  validates :schedule_kind, presence: true, inclusion: { in: SCHEDULE_KINDS }
  validates :schedule_hour, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 23 }
  validates :schedule_minute, presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 59 }
  validates :schedule_day, presence: true, if: -> { schedule_kind.in?(%w[weekly monthly]) }
  validates :schedule_day, numericality: { only_integer: true, in: 0..6 }, if: -> { schedule_kind == "weekly" }
  # Capped at 28 so every month has the day — no silent skipping in February.
  validates :schedule_day, numericality: { only_integer: true, in: 1..28 }, if: -> { schedule_kind == "monthly" }
  validate :at_least_one_recipient
  validate :external_emails_are_valid

  before_validation :normalise_recipients
  before_save :set_next_run_at, if: :schedule_changed?

  scope :active, -> { where(active: true) }
  scope :due, ->(now = Time.current) { active.where(next_run_at: ..now) }

  # The form uses a single <input type="time">; the schedule is stored as two
  # integers so it stays comparable and time-zone independent.
  def schedule_time
    format("%02d:%02d", schedule_hour.to_i, schedule_minute.to_i)
  end

  def schedule_time=(value)
    hours, minutes = value.to_s.split(":")
    return if hours.blank?

    self.schedule_hour = hours.to_i
    self.schedule_minute = minutes.to_i
  end

  # Human label for the period a run covered — goes in the subject line so a
  # digest is identifiable in an inbox without opening it.
  def period_label(period)
    reference = (period.last || Time.current).in_time_zone(time_zone)

    case schedule_kind
    when "daily"   then I18n.l(reference.to_date, format: :short)
    when "monthly" then I18n.l(reference.to_date, format: :month_year, default: reference.strftime("%m/%Y"))
    else I18n.t("mailers.automation_mailer.digest.week", number: reference.strftime("%V"))
    end
  end

  def report
    @report ||= Automations::Registry.build(kind, automation: self)
  end

  def org_member_ids
    Array(recipients["org_member_ids"]).map(&:to_i)
  end

  def external_emails
    Array(recipients["external_emails"])
  end

  # Internal members first, then externals. Deduplicated — the same address can
  # legitimately appear on both sides.
  def recipient_emails
    internal = organisation.org_members
                           .accepted
                           .where(active: true, id: org_member_ids)
                           .joins(:member)
                           .pluck("members.email")

    (internal + external_emails).map { |e| e.to_s.strip.downcase }.reject(&:blank?).uniq
  end

  def external_recipients?
    external_emails.any?
  end

  # The window the next run covers. Anchored on last_run_at so no event is
  # missed or counted twice when a run is late; falls back to one schedule
  # period on the first run.
  def period_for(now: Time.current)
    start_at = last_run_at || (now - default_lookback)
    start_at..now
  end

  def default_lookback
    case schedule_kind
    when "daily"   then 1.day
    when "monthly" then 1.month
    else 1.week
    end
  end

  def time_zone
    ActiveSupport::TimeZone[organisation.timezone] || Time.zone
  end

  # Next firing strictly after `from`, in the organisation's own time zone —
  # "Friday at 9" has to mean 9 in Lisbon, not 9 UTC (an hour off all summer).
  def compute_next_run_at(from: Time.current)
    local = from.in_time_zone(time_zone)

    candidate = case schedule_kind
    when "daily"
      local.change(hour: schedule_hour, min: schedule_minute.to_i, sec: 0)
    when "weekly"
      day = local.change(hour: schedule_hour, min: schedule_minute.to_i, sec: 0)
      day + ((schedule_day.to_i - day.wday) % 7).days
    when "monthly"
      local.change(day: schedule_day.to_i, hour: schedule_hour, min: schedule_minute.to_i, sec: 0)
    end

    candidate = advance(candidate) while candidate <= local
    candidate.utc
  end

  def set_next_run_at!
    update_column(:next_run_at, compute_next_run_at)
  end

  private

  def advance(candidate)
    case schedule_kind
    when "daily"   then candidate + 1.day
    when "weekly"  then candidate + 1.week
    when "monthly" then candidate + 1.month
    end
  end

  def schedule_changed?
    new_record? || schedule_kind_changed? || schedule_day_changed? ||
      schedule_hour_changed? || schedule_minute_changed? || (active_changed? && active?)
  end

  def set_next_run_at
    self.next_run_at = compute_next_run_at
  end

  def normalise_recipients
    self.recipients ||= {}
    self.recipients = recipients.slice("org_member_ids", "external_emails")
    self.recipients["org_member_ids"] = Array(recipients["org_member_ids"]).map(&:to_i).uniq
    self.recipients["external_emails"] =
      Array(recipients["external_emails"]).map { |e| e.to_s.strip.downcase }.reject(&:blank?).uniq
  end

  def at_least_one_recipient
    return if org_member_ids.any? || external_emails.any?

    errors.add(:recipients, :blank)
  end

  def external_emails_are_valid
    invalid = external_emails.reject { |e| e.match?(URI::MailTo::EMAIL_REGEXP) }
    return if invalid.empty?

    errors.add(:recipients, :invalid_email, emails: invalid.join(", "))
  end
end
