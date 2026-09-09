require "test_helper"
require "minitest/mock"

module Erp
  # A real order failed to reach the ERP because of a SKU that did not exist
  # there. Once the line was corrected, "retry" left the order at `pending`
  # forever: the attempt budget was spent, the service refused without saying
  # so, and the retry button only shows for `failed` — so it disappeared at the
  # moment it was needed.
  class OrderPushServiceTest < ActiveSupport::TestCase
    # Stands in for the Firebird adapter, which cannot be reached from a test
    # (or from a development machine).
    class FakeAdapter
      attr_reader :pushed

      def initialize(response = { success: true, external_id: "ERP-1" })
        @response = response
        @pushed = []
      end

      def supports_push? = true

      def push_order(payload)
        @pushed << payload
        @response
      end
    end

    setup do
      @organisation = Organisation.create!(name: "Push Org", currency: "EUR")
      @erp_config = ErpConfiguration.create!(
        organisation: @organisation, enabled: true, adapter_type: "custom_api",
        credentials: { base_url: "https://erp.exemplo.pt", api_key: "k" },
        sync_frequency: "daily", product_sync_mode: "update_only", sync_orders: true
      )
      @customer = @organisation.customers.create!(company_name: "Cliente", contact_name: "Rui",
                                                  active: true, external_id: "C-1")
      @login = @customer.customer_users.create!(organisation: @organisation, contact_name: "Rui",
                                                email: "rui-push@exemplo.pt", password: "password123")
      @order = @organisation.orders.create!(customer: @customer, customer_user: @login,
                                            status: "in_process", placed_at: Time.current)
    end

    # The service loads its own copy of the configuration, so the adapter is
    # stubbed on that one — there is no Firebird to talk to from a test.
    def push(adapter = FakeAdapter.new)
      service = OrderPushService.new(order: @order)
      config = service.instance_variable_get(:@erp_config)

      config.stub(:adapter, adapter) { service.call }
    end

    test "a successful push marks the order synced" do
      result = push

      assert result.success?
      assert_equal "synced", @order.reload.push_status
    end

    # The bug, in one test: an order that has spent its attempts must not be
    # left looking like it is still on its way.
    test "an order out of attempts is recorded as failed, not left pending" do
      @order.update!(push_attempts: Order::MAX_PUSH_ATTEMPTS, push_status: "pending")

      result = push

      assert_not result.success?
      assert_equal "failed", @order.reload.push_status
      assert_match(/attempts exhausted/i, @order.sync_error)
    end

    test "an order whose customer is unknown to the ERP says so" do
      @customer.update!(external_id: nil)

      result = push

      assert_not result.success?
      assert_equal "failed", @order.reload.push_status
      assert_match(/external_id/, @order.sync_error)
    end

    # These say nothing about the order itself, so they must not brand it.
    test "an already synced order is left untouched" do
      @order.update!(push_status: "synced", push_attempts: 1)

      push

      assert_equal "synced", @order.reload.push_status
      assert_nil @order.sync_error
    end

    test "a draft order is not branded as failed" do
      @order.update!(placed_at: nil, push_status: "pending")

      push

      assert_equal "pending", @order.reload.push_status
      assert_nil @order.sync_error
    end
  end
end
