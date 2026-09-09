require "test_helper"

# The whole round trip a person actually took: the order failed, they fixed the
# lines, they pressed retry — and nothing happened, quietly.
class Bo::OrderRetryPushTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @organisation = Organisation.create!(name: "Retry Org", currency: "EUR")
    @admin = Member.create!(email: "retry-admin@example.com", password: "password123",
                            first_name: "Ana", last_name: "Admin")
    @organisation.org_members.create!(member: @admin, role: "owner", active: true)
    ErpConfiguration.create!(
      organisation: @organisation, enabled: true, adapter_type: "custom_api",
      credentials: { base_url: "https://erp.exemplo.pt", api_key: "k" },
      sync_frequency: "daily", product_sync_mode: "update_only", sync_orders: true
    )
    sign_in @admin

    @customer = @organisation.customers.create!(company_name: "Cliente", contact_name: "Rui",
                                                active: true, external_id: "C-1")
    @login = @customer.customer_users.create!(organisation: @organisation, contact_name: "Rui",
                                              email: "rui-retry@exemplo.pt", password: "password123")
    @order = @organisation.orders.create!(customer: @customer, customer_user: @login,
                                          status: "in_process", placed_at: Time.current)
  end

  def retry_push
    post retry_push_bo_order_path(org_slug: @organisation.slug, id: @order.id)
    @order.reload
  end

  # The fix. Pressing retry is a person saying "I corrected it" — the attempt
  # budget starts over, or the push refuses itself the moment it is queued.
  test "retrying gives an exhausted order its attempts back" do
    @order.update!(push_status: "failed", push_attempts: Order::MAX_PUSH_ATTEMPTS,
                   sync_error: "SKU not found", last_pushed_at: 1.minute.ago)

    retry_push

    assert_equal 0, @order.push_attempts
    assert_equal "pending", @order.push_status
    assert_nil @order.sync_error
    assert_not @order.push_exhausted?
  end

  test "retrying clears the cooldown so the order is picked up at once" do
    @order.update!(push_status: "failed", push_attempts: 2, last_pushed_at: 1.minute.ago)

    retry_push

    assert_includes Order.pushable, @order
  end

  test "retrying queues the push" do
    @order.update!(push_status: "failed", push_attempts: Order::MAX_PUSH_ATTEMPTS)

    assert_enqueued_with(job: OrderPushJob, args: [ @order.id ]) do
      post retry_push_bo_order_path(org_slug: @organisation.slug, id: @order.id)
    end
  end

  # The button used to be shown only for `failed`, so one press moved the order
  # to `pending` and the way back disappeared with it.
  test "the button is still there for an order stuck after a retry" do
    @order.update!(push_status: "pending", push_attempts: Order::MAX_PUSH_ATTEMPTS)

    get bo_orders_path(org_slug: @organisation.slug)

    assert_response :success
    assert_select "form[action=?]", retry_push_bo_order_path(org_slug: @organisation.slug, id: @order.id)
  end

  test "the button is there for a push stuck part-way" do
    @order.update!(push_status: "syncing", push_attempts: 1, last_pushed_at: 2.hours.ago)

    get bo_orders_path(org_slug: @organisation.slug)

    assert_select "form[action=?]", retry_push_bo_order_path(org_slug: @organisation.slug, id: @order.id)
  end

  test "no button for an order on its way to the ERP" do
    @order.update!(push_status: "pending", push_attempts: 0)

    get bo_orders_path(org_slug: @organisation.slug)

    assert_select "form[action='#{retry_push_bo_order_path(org_slug: @organisation.slug, id: @order.id)}']", count: 0
  end
end
