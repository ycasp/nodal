require "test_helper"

class AutomationTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(
      name: "Test Org",
      slug: "test-org-#{SecureRandom.hex(4)}",
      currency: "EUR",
      tax_rate: 0.23,
      timezone: "Europe/Lisbon"
    )
  end

  def build_automation(**overrides)
    Automation.new({
      organisation: @organisation,
      name: "Rupturas semanais",
      kind: "out_of_stock_digest",
      schedule_kind: "weekly",
      schedule_day: 5,
      schedule_hour: 9,
      recipients: { "external_emails" => [ "fornecedor@exemplo.pt" ] }
    }.merge(overrides))
  end

  test "a valid weekly automation saves" do
    assert build_automation.save
  end

  test "an unknown kind is rejected" do
    automation = build_automation(kind: "does_not_exist")
    assert_not automation.valid?
    assert_includes automation.errors[:kind], "is not included in the list"
  end

  test "an automation with no recipients at all is rejected" do
    automation = build_automation(recipients: {})
    assert_not automation.valid?
    assert automation.errors[:recipients].any?
  end

  test "a malformed external email is rejected" do
    automation = build_automation(recipients: { "external_emails" => [ "nao-e-um-email" ] })
    assert_not automation.valid?
    assert automation.errors[:recipients].any?
  end

  test "external emails are downcased and deduplicated" do
    automation = build_automation(
      recipients: { "external_emails" => [ " Fornecedor@Exemplo.PT ", "fornecedor@exemplo.pt" ] }
    )
    assert automation.save
    assert_equal [ "fornecedor@exemplo.pt" ], automation.external_emails
  end

  test "unknown recipient keys are dropped" do
    automation = build_automation(
      recipients: { "external_emails" => [ "a@b.pt" ], "customer_ids" => [ 1 ] }
    )
    automation.save!
    assert_equal %w[org_member_ids external_emails].sort, automation.recipients.keys.sort
  end

  test "next_run_at is set on create and lands on the scheduled weekday and hour" do
    automation = build_automation
    automation.save!

    local = automation.next_run_at.in_time_zone("Europe/Lisbon")
    assert_equal 5, local.wday, "must fall on a Friday"
    assert_equal 9, local.hour, "must be 9 in the org's own time zone"
    assert automation.next_run_at > Time.current
  end

  test "the hour is interpreted in the organisation time zone, not UTC" do
    # Lisbon is UTC+1 in August; 9 local must not be stored as 9 UTC.
    travel_to Time.utc(2026, 8, 3, 12, 0) do
      automation = build_automation
      automation.save!
      assert_equal 8, automation.next_run_at.utc.hour
    end
  end

  test "a schedule change recomputes next_run_at" do
    automation = build_automation
    automation.save!
    before = automation.next_run_at

    automation.update!(schedule_day: 1)
    assert_not_equal before, automation.next_run_at
    assert_equal 1, automation.next_run_at.in_time_zone("Europe/Lisbon").wday
  end

  test "monthly schedules are capped at day 28 so no month is skipped" do
    automation = build_automation(schedule_kind: "monthly", schedule_day: 31)
    assert_not automation.valid?
  end

  test "the due scope only picks active automations whose time has come" do
    due      = build_automation
    not_due  = build_automation
    inactive = build_automation(active: false)
    [ due, not_due, inactive ].each(&:save!)

    due.update_column(:next_run_at, 1.minute.ago)
    not_due.update_column(:next_run_at, 1.hour.from_now)
    inactive.update_column(:next_run_at, 1.minute.ago)

    assert_includes Automation.due, due
    assert_not_includes Automation.due, not_due
    assert_not_includes Automation.due, inactive
  end

  test "the schedule accepts hours and minutes" do
    automation = build_automation(schedule_time: "09:30")
    automation.save!

    assert_equal 9, automation.schedule_hour
    assert_equal 30, automation.schedule_minute
    assert_equal "09:30", automation.schedule_time
    assert_equal 30, automation.next_run_at.in_time_zone("Europe/Lisbon").min
  end

  test "changing only the minutes recomputes next_run_at" do
    automation = build_automation
    automation.save!
    before = automation.next_run_at

    automation.update!(schedule_time: "09:45")
    assert_not_equal before, automation.next_run_at
    assert_equal 45, automation.next_run_at.in_time_zone("Europe/Lisbon").min
  end

  test "the weekly period label carries the week number" do
    automation = build_automation
    automation.save!

    period = Time.utc(2026, 8, 31)..Time.utc(2026, 9, 4)
    assert_match(/36/, automation.period_label(period))
  end

  test "the first period looks back one schedule length" do
    automation = build_automation
    automation.save!

    period = automation.period_for(now: Time.current)
    assert_in_delta 7.days, period.last - period.first, 60
  end

  test "later periods start where the last run ended" do
    automation = build_automation
    automation.save!
    automation.update_column(:last_run_at, 3.days.ago)

    assert_in_delta 3.days.ago, automation.period_for.first, 60
  end
end
