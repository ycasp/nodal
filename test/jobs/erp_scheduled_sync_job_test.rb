require "test_helper"

class ErpScheduledSyncJobTest < ActiveJob::TestCase
  setup do
    @organisation = organisation_with_erp(frequency: "daily")
  end

  def organisation_with_erp(frequency:, enabled: true, adapter_type: "custom_api")
    org = Organisation.create!(
      name: "Test Org", slug: "test-org-#{SecureRandom.hex(4)}",
      currency: "EUR", tax_rate: 0.23, timezone: "Europe/Lisbon"
    )
    ErpConfiguration.create!(
      organisation: org,
      enabled: enabled,
      adapter_type: adapter_type,
      credentials: { base_url: "https://erp.exemplo.pt", api_key: "k" },
      sync_frequency: frequency,
      product_sync_mode: "update_only"
    )
    org
  end

  # Enqueued args come back serialized; deserialize so the kwargs read as kwargs.
  def enqueued_sync_calls
    enqueued_jobs.select { |j| j[:job] == ErpSyncJob }.map do |j|
      ActiveJob::Arguments.deserialize(j[:args])
    end
  end

  test "enqueues a sync for each organisation on the matching frequency" do
    ErpScheduledSyncJob.perform_now("daily")

    calls = enqueued_sync_calls
    assert_equal 1, calls.size
    assert_equal @organisation.id, calls.first.first
  end

  # The regression guard. ErpScheduledSyncJob writes a sync_type that
  # ErpSyncLog has to accept: when the two drifted apart, every nightly sync
  # died on ErpSyncLog.start! with RecordInvalid and no scheduled sync ran for
  # five months — silently, because the failure lived only in the job backlog.
  # Asserting the literal string on both sides would let a rename pass, so
  # feed what the job actually enqueues straight into the validation.
  test "enqueues a sync_type that ErpSyncLog accepts" do
    ErpScheduledSyncJob.perform_now("daily")

    sync_type = enqueued_sync_calls.first.last[:sync_type]
    assert sync_type.present?, "the scheduled job must say how the sync was triggered"

    log = ErpSyncLog.new(
      organisation: @organisation,
      erp_configuration: @organisation.erp_configuration,
      sync_type: sync_type,
      entity_type: "products",
      status: "running"
    )
    assert log.valid?, "ErpSyncLog rejects the sync_type the scheduled job enqueues: #{log.errors.full_messages.join(', ')}"
  end

  test "leaves organisations on another frequency alone" do
    organisation_with_erp(frequency: "weekly")

    ErpScheduledSyncJob.perform_now("hourly")

    assert_empty enqueued_sync_calls
  end

  test "skips organisations whose ERP is disabled" do
    ErpConfiguration.find_by(organisation: @organisation).update_column(:enabled, false)

    ErpScheduledSyncJob.perform_now("daily")

    assert_empty enqueued_sync_calls
  end

  test "skips organisations with no adapter configured" do
    ErpConfiguration.find_by(organisation: @organisation).update_column(:adapter_type, nil)

    ErpScheduledSyncJob.perform_now("daily")

    assert_empty enqueued_sync_calls
  end
end
