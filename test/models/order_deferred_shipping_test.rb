require "test_helper"

# Covers the "shipping calculated before dispatch" mode: the customer checks out
# without a shipping amount, and the back office prices it once the order is
# packed.
class OrderDeferredShippingTest < ActiveSupport::TestCase
  def setup
    @org = Organisation.create!(name: "Deferred Shipping Org", shipping_cost: 15, tax_rate: 0)
    @customer = Customer.create!(organisation: @org, company_name: "Acme", contact_name: "Jane", active: true)
    @customer_user = CustomerUser.create!(organisation: @org, customer: @customer,
      email: "jane@deferred.test", password: "password123", password_confirmation: "password123",
      contact_name: "Jane", active: true)
    @product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000, published: true)
    @order = Order.create!(customer: @customer, customer_user: @customer_user, organisation: @org,
                           delivery_method: "delivery")
    @order.order_items.create!(product: @product, quantity: 1)
    @order.reload
  end

  def place!(order)
    order.terms_accepted_at = Time.current
    order.finalize_checkout!
    order.reload
  end

  test "fixed mode is unchanged: the flat rate is charged at checkout" do
    place!(@order)

    assert_not @order.shipping_pending?
    assert_equal Money.new(1500, "EUR"), @order.shipping_amount
    assert_equal Money.new(1000 + 1500, "EUR"), @order.grand_total
  end

  test "deferred mode leaves the amount blank and flags the order as pending" do
    @org.update!(shipping_mode: "calculated_on_dispatch")

    place!(@order)

    assert @order.shipping_pending?
    assert_nil @order.shipping_amount
    assert_equal Money.new(0, "EUR"), @order.effective_shipping
    # Total is the goods only — no phantom flat rate.
    assert_equal Money.new(1000, "EUR"), @order.grand_total
  end

  test "pickup is settled at checkout even in deferred mode" do
    @org.update!(shipping_mode: "calculated_on_dispatch")
    @order.update!(delivery_method: "pickup")

    place!(@order)

    assert_not @order.shipping_pending?
    assert_equal Money.new(0, "EUR"), @order.shipping_amount
  end

  test "free shipping is settled at checkout even in deferred mode" do
    @org.update!(shipping_mode: "calculated_on_dispatch", free_shipping_threshold: 5)

    place!(@order)

    assert_not @order.shipping_pending?
    assert_equal Money.new(0, "EUR"), @order.shipping_amount
  end

  test "pricing the shipping closes the pending state and the total" do
    @org.update!(shipping_mode: "calculated_on_dispatch")
    place!(@order)

    @order.update!(shipping_amount: 22.35)
    @order.reload

    assert_not @order.shipping_pending?
    assert_equal Money.new(2235, "EUR"), @order.effective_shipping
    assert_equal Money.new(1000 + 2235, "EUR"), @order.grand_total
  end

  test "clearing the amount puts the order back into to-be-calculated" do
    @org.update!(shipping_mode: "calculated_on_dispatch")
    place!(@order)
    @order.update!(shipping_amount: 22.35)

    @order.update!(shipping_amount: nil, shipping_pending: true)
    @order.reload

    assert @order.shipping_pending?
    assert_equal Money.new(1000, "EUR"), @order.grand_total
  end

  test "switching the org back to fixed does not charge a placed pending order" do
    @org.update!(shipping_mode: "calculated_on_dispatch")
    place!(@order)

    @org.update!(shipping_mode: "fixed")
    @order.reload

    assert @order.shipping_pending?, "the snapshot taken at checkout must survive the setting change"
    assert_equal Money.new(1000, "EUR"), @order.grand_total
  end

  test "a cart answers from the organisation's current setting" do
    assert_not @order.shipping_pending?

    @org.update!(shipping_mode: "calculated_on_dispatch")
    @order.reload

    assert @order.draft?
    assert @order.shipping_pending?
    assert_equal Money.new(0, "EUR"), @order.calculated_shipping
  end

  test "shipping_mode only accepts known values" do
    @org.shipping_mode = "whenever"

    assert_not @org.valid?
    assert_includes @org.errors.attribute_names, :shipping_mode
  end
end
