require "test_helper"

class CartHelperTest < ActionView::TestCase
  def setup
    @org = Organisation.create!(name: "Badge Org")
    @customer = Customer.create!(organisation: @org, company_name: "Acme", contact_name: "Jane", active: true)
    @customer_user = CustomerUser.create!(organisation: @org, customer: @customer,
      email: "jane@acme.test", password: "password123", password_confirmation: "password123",
      contact_name: "Jane", active: true)
    @product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000, published: true)
    @order = Order.create!(customer: @customer, customer_user: @customer_user, organisation: @org)
  end

  test "qty_overflow shows a badge only under the warn policy" do
    item = @order.order_items.create!(product: @product, quantity: 5)
    @product.default_variant.update!(track_stock: true, stock_quantity: 2, stock_policy: "show_badge")
    item.reload
    assert_equal :qty_overflow, item.stock_status

    @org.update!(cart_qty_overflow_policy: "allow")
    assert_nil cart_stock_badge(item.tap(&:reload))

    @org.update!(cart_qty_overflow_policy: "warn")
    assert_match(/2/, cart_stock_badge(item.tap(&:reload)))
  end

  test "out_of_stock shows a badge only under the warn policy" do
    item = @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(track_stock: true, stock_quantity: 0, stock_policy: "show_badge")
    item.reload
    assert_equal :out_of_stock, item.stock_status

    @org.update!(cart_stock_policy: "allow")
    assert_nil cart_stock_badge(item.tap(&:reload))

    @org.update!(cart_stock_policy: "warn")
    assert_not_nil cart_stock_badge(item.tap(&:reload))
  end
end
