require "test_helper"

class PromoCodeTest < ActiveSupport::TestCase
  def setup
    @org = Organisation.create!(name: "Promo Test Org")
    @customer = Customer.create!(organisation: @org, company_name: "Acme", contact_name: "J", active: true)
    @cu = CustomerUser.create!(organisation: @org, customer: @customer, email: "j@acme.test",
      password: "password123", password_confirmation: "password123", contact_name: "J", active: true)
    @product = Product.create!(organisation: @org, name: "Widget", unit_price: 10000, published: true) # €100
    @order = Order.create!(customer: @customer, customer_user: @cu, organisation: @org)
    @order.order_items.create!(product: @product, quantity: 1) # €100 line total
    @promo = PromoCode.create!(organisation: @org, code: "SAVE20", discount_type: "percentage",
      discount_value: 0.20, eligibility: "all_customers", active: true, stackable: false)
  end

  def add_order_tier!
    OrderDiscount.create!(organisation: @org, discount_type: "percentage", discount_value: 0.10,
      min_order_amount_cents: 100, active: true)
  end

  test "non-stackable promo is allowed when there is no other order-level discount" do
    assert_equal :ok, @promo.redeemable_by?(@customer, @order)
  end

  test "non-stackable promo is blocked when an order tier discount applies" do
    add_order_tier!
    assert_equal :not_stackable, @promo.redeemable_by?(@customer, @order)
  end

  test "stackable promo is allowed even with an order tier discount" do
    @promo.update!(stackable: true)
    add_order_tier!
    assert_equal :ok, @promo.redeemable_by?(@customer, @order)
  end

  test "non-stackable promo is blocked when a manual order discount is set" do
    @order.discount_type = "percentage"
    @order.discount_value = 0.05
    assert_equal :not_stackable, @promo.redeemable_by?(@customer, @order)
  end

  test "non-stackable promo still combines with line-level discounts (base pricing)" do
    # A customer tier discount is line-level — it must NOT block the promo.
    CustomerDiscount.create!(organisation: @org, customer: @customer,
      discount_type: "percentage", discount_value: 0.06, active: true)
    assert_equal :ok, @promo.redeemable_by?(@customer, @order)
  end
end
