require "test_helper"

class CartDiscountNudgesTest < ActiveSupport::TestCase
  def setup
    @org = Organisation.create!(name: "Nudge Test Org")
    @customer = Customer.create!(organisation: @org, company_name: "Acme", contact_name: "J", active: true)
    @cu = CustomerUser.create!(organisation: @org, customer: @customer, email: "j@acme.test",
      password: "password123", password_confirmation: "password123", contact_name: "J", active: true)
    @product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000, published: true) # €10
    @order = Order.create!(organisation: @org, customer: @customer, customer_user: @cu)
  end

  def nudges
    CartDiscountNudges.new(@order).opportunities
  end

  test "surfaces an opportunity when the customer is close to a quantity threshold" do
    ProductDiscount.create!(organisation: @org, product: @product, discount_type: "percentage",
      discount_value: 0.15, condition_type: "quantity", min_quantity: 10)
    @order.order_items.create!(product: @product, quantity: 7) # 70% of 10

    ops = nudges
    assert_equal 1, ops.size
    op = ops.first
    assert_equal "Widget", op.label
    assert_equal "-15%", op.discount_label
    assert_equal 3, op.remaining
    assert_in_delta 0.7, op.progress, 0.001
  end

  test "stays quiet when the customer is far from the threshold" do
    ProductDiscount.create!(organisation: @org, product: @product, discount_type: "percentage",
      discount_value: 0.15, condition_type: "quantity", min_quantity: 10)
    @order.order_items.create!(product: @product, quantity: 3) # 30% -> below 65%

    assert_empty nudges
  end

  test "stays quiet once the discount is already unlocked" do
    ProductDiscount.create!(organisation: @org, product: @product, discount_type: "percentage",
      discount_value: 0.15, condition_type: "quantity", min_quantity: 10)
    @order.order_items.create!(product: @product, quantity: 10) # 100% -> already met

    assert_empty nudges
  end

  test "celebrates a discount once its threshold is reached" do
    ProductDiscount.create!(organisation: @org, product: @product, discount_type: "percentage",
      discount_value: 0.15, condition_type: "quantity", min_quantity: 10)
    @order.order_items.create!(product: @product, quantity: 12) # met

    assert_empty CartDiscountNudges.new(@order).opportunities # no longer "almost"
    unlocked = CartDiscountNudges.new(@order).unlocked
    assert_equal 1, unlocked.size
    assert_equal "-15%", unlocked.first.discount_label
    # 15% of €120 (12 × €10) currently in the cart
    assert_equal Money.new(1800, "EUR"), unlocked.first.reward
  end

  test "does not celebrate a discount that isn't reached yet" do
    ProductDiscount.create!(organisation: @org, product: @product, discount_type: "percentage",
      discount_value: 0.15, condition_type: "quantity", min_quantity: 10)
    @order.order_items.create!(product: @product, quantity: 7)

    assert_empty CartDiscountNudges.new(@order).unlocked
  end

  test "surfaces a € amount threshold with the amount remaining" do
    ProductDiscount.create!(organisation: @org, product: @product, discount_type: "percentage",
      discount_value: 0.10, condition_type: "amount", min_amount_cents: 10000) # €100
    @order.order_items.create!(product: @product, quantity: 7) # €70 = 70%

    op = nudges.first
    assert op
    assert_equal Money.new(3000, "EUR"), op.remaining
    assert_equal Money.new(1000, "EUR"), op.reward # 10% of the €100 threshold
  end

  # Regression: the aggregate (summed/category) path wrapped the result with
  # Array(), which decomposed the Struct into its field values — the view then
  # got a String and raised "undefined method discount_label".
  test "summed unlocked returns an Unlocked struct, not its decomposed fields" do
    ProductDiscount.create!(organisation: @org, product: @product, discount_type: "percentage",
      discount_value: 0.15, condition_type: "quantity", min_quantity: 10, condition_scope: "summed")
    @order.order_items.create!(product: @product, quantity: 12) # met

    unlocked = CartDiscountNudges.new(@order).unlocked
    assert_equal 1, unlocked.size
    assert_instance_of CartDiscountNudges::Unlocked, unlocked.first
    assert_equal "-15%", unlocked.first.discount_label
  end
end
