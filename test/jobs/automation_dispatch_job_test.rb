require "test_helper"

class AutomationDispatchJobTest < ActiveJob::TestCase
  setup do
    @organisation = Organisation.create!(
      name: "Test Org", slug: "test-org-#{SecureRandom.hex(4)}",
      currency: "EUR", tax_rate: 0.23, timezone: "Europe/Lisbon"
    )
  end

  def automation(active: true)
    Automation.create!(
      organisation: @organisation,
      name: "Digest #{SecureRandom.hex(3)}",
      kind: "out_of_stock_digest",
      schedule_kind: "weekly", schedule_day: 5, schedule_hour: 9,
      active: active,
      recipients: { "external_emails" => [ "a@exemplo.pt" ] }
    )
  end

  test "enqueues a run for each due automation" do
    due = automation
    due.update_column(:next_run_at, 1.minute.ago)

    assert_enqueued_with(job: AutomationRunJob, args: [ due.id ]) do
      AutomationDispatchJob.perform_now
    end
  end

  test "leaves automations that are not due alone" do
    automation.update_column(:next_run_at, 2.hours.from_now)

    assert_no_enqueued_jobs only: AutomationRunJob do
      AutomationDispatchJob.perform_now
    end
  end

  test "leaves inactive automations alone even when due" do
    automation(active: false).update_column(:next_run_at, 1.minute.ago)

    assert_no_enqueued_jobs only: AutomationRunJob do
      AutomationDispatchJob.perform_now
    end
  end
end
