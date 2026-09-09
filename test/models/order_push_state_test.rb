require "test_helper"

# Which orders the retry picks up, and which ones a person is offered a button
# for. Both used to leave orders in a place nothing could reach: an order that
# spent its attempts sat at `pending` with no button, and one killed mid-push
# sat at `syncing` where the retry never looked — two did, in production, from
# May to September.
class OrderPushStateTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(name: "Push State Org", currency: "EUR")
    @customer = @organisation.customers.create!(company_name: "Cliente", contact_name: "Rui", active: true)
    @login = @customer.customer_users.create!(organisation: @organisation, contact_name: "Rui",
                                              email: "rui-state@exemplo.pt", password: "password123")
  end

  def order(placed: true, **attrs)
    @organisation.orders.create!(
      customer: @customer, customer_user: @login, status: "in_process",
      placed_at: placed ? Time.current : nil, **attrs
    )
  end

  test "picks up an order waiting to be pushed" do
    waiting = order(push_status: "pending")

    assert_includes Order.pushable, waiting
  end

  test "picks up a failed order once the cooldown has passed" do
    failed = order(push_status: "failed", push_attempts: 1, last_pushed_at: 20.minutes.ago)

    assert_includes Order.pushable, failed
  end

  test "leaves a failed order alone during the cooldown" do
    just_tried = order(push_status: "failed", push_attempts: 1, last_pushed_at: 1.minute.ago)

    assert_not_includes Order.pushable, just_tried
  end

  # The push is marked `syncing` before the ERP is called, so a killed process
  # leaves it there. Nothing used to look at that state again.
  test "picks up a push that started and never finished" do
    stuck = order(push_status: "syncing", push_attempts: 1, last_pushed_at: 2.hours.ago)

    assert_includes Order.pushable, stuck
  end

  test "leaves a push that is genuinely in flight alone" do
    in_flight = order(push_status: "syncing", push_attempts: 1, last_pushed_at: 1.minute.ago)

    assert_not_includes Order.pushable, in_flight
  end

  test "leaves a synced order alone" do
    assert_not_includes Order.pushable, order(push_status: "synced")
  end

  test "leaves a draft alone" do
    assert_not_includes Order.pushable, order(placed: false, push_status: "pending")
  end

  test "leaves an order that spent its attempts to a person" do
    exhausted = order(push_status: "pending", push_attempts: Order::MAX_PUSH_ATTEMPTS)

    assert_not_includes Order.pushable, exhausted
    assert exhausted.push_stuck?, "a person must be offered the chance to send it again"
  end

  test "offers the button for a failed order" do
    assert order(push_status: "failed", push_attempts: 1).push_stuck?
  end

  test "offers the button for a push stuck part-way" do
    assert order(push_status: "syncing", push_attempts: 1, last_pushed_at: 2.hours.ago).push_stuck?
  end

  test "does not offer the button while a push is in flight" do
    assert_not order(push_status: "syncing", push_attempts: 1, last_pushed_at: 1.minute.ago).push_stuck?
  end

  test "does not offer the button for an order still on its way" do
    assert_not order(push_status: "pending", push_attempts: 1).push_stuck?
  end

  test "does not offer the button for a synced order" do
    assert_not order(push_status: "synced").push_stuck?
  end

  # Found while testing the push: emptying an order of its lines and saving it
  # raised NoMethodError, because summing no lines gives an integer and every
  # caller treats the total as Money.
  test "an order with no lines still has a total" do
    empty = order(push_status: "pending")

    assert_equal 0, empty.total_amount.cents
    assert_nothing_raised { empty.save! }
  end
end
