require "test_helper"

class ReapStalledBackgroundTasksJobTest < ActiveJob::TestCase
  setup do
    @organisation = Organisation.create!(
      name: "Test Org", slug: "test-org-#{SecureRandom.hex(4)}",
      currency: "EUR", tax_rate: 0.23, timezone: "Europe/Lisbon",
      default_locale: "pt"
    )
    @member = Member.create!(
      email: "member-#{SecureRandom.hex(4)}@exemplo.pt",
      password: "password123", first_name: "Ana", last_name: "Silva"
    )
  end

  def task(status:, started_at: nil, created_at: Time.current)
    BackgroundTask.create!(
      organisation: @organisation, member: @member, task_type: "generate_catalog",
      status: status, started_at: started_at, created_at: created_at
    )
  end

  test "closes a task still running long past the limit" do
    stalled = task(status: :running, started_at: 3.hours.ago)

    ReapStalledBackgroundTasksJob.perform_now

    assert_equal "failed", stalled.reload.status
    assert_not_nil stalled.completed_at
  end

  test "leaves a task that is still within the limit alone" do
    working = task(status: :running, started_at: 30.minutes.ago)

    ReapStalledBackgroundTasksJob.perform_now

    assert_equal "running", working.reload.status
  end

  # A task whose job was never picked up has no started_at at all, so the age
  # has to fall back to when it was created — otherwise it is never reaped.
  test "closes a task that was never picked up" do
    never_started = task(status: :pending, created_at: 5.hours.ago)

    ReapStalledBackgroundTasksJob.perform_now

    assert_equal "failed", never_started.reload.status
  end

  test "leaves a recently queued task alone" do
    queued = task(status: :pending, created_at: 2.minutes.ago)

    ReapStalledBackgroundTasksJob.perform_now

    assert_equal "pending", queued.reload.status
  end

  test "does not touch tasks that already finished" do
    %i[completed failed cancelled].each do |status|
      finished = task(status: status, started_at: 8.hours.ago)

      ReapStalledBackgroundTasksJob.perform_now

      assert_equal status.to_s, finished.reload.status
    end
  end

  test "explains itself in the organisation's language" do
    stalled = task(status: :running, started_at: 3.hours.ago)

    ReapStalledBackgroundTasksJob.perform_now

    message = stalled.reload.error_message
    assert_match(/2h/, message)
    assert_equal I18n.t("bo.background_tasks.stalled", hours: 2, locale: :pt), message
  end
end
