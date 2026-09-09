require "test_helper"

class ErpSyncLogTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(
      name: "Test Org", slug: "test-org-#{SecureRandom.hex(4)}",
      currency: "EUR", tax_rate: 0.23, timezone: "Europe/Lisbon"
    )
    @erp_configuration = ErpConfiguration.create!(
      organisation: @organisation,
      enabled: true,
      adapter_type: "custom_api",
      credentials: { base_url: "https://erp.exemplo.pt", api_key: "k" },
      sync_frequency: "daily",
      product_sync_mode: "update_only"
    )
  end

  def log(sync_type:)
    ErpSyncLog.new(
      organisation: @organisation,
      erp_configuration: @erp_configuration,
      sync_type: sync_type,
      entity_type: "products",
      status: "running"
    )
  end

  test "accepts every sync type the app actually writes" do
    %w[full incremental manual scheduled].each do |sync_type|
      assert log(sync_type: sync_type).valid?, "#{sync_type} should be a valid sync type"
    end
  end

  test "rejects an unknown sync type" do
    refute log(sync_type: "nightly").valid?
  end

  test "start! records a running sync" do
    record = ErpSyncLog.start!(
      organisation: @organisation,
      erp_configuration: @erp_configuration,
      sync_type: "scheduled",
      entity_type: "products"
    )

    assert record.persisted?
    assert record.running?
    assert_not_nil record.started_at
  end
end
