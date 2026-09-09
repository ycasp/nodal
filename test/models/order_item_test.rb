require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  def setup
    @org = Organisation.create!(name: "Refresh Test Org")
    @customer = Customer.create!(organisation: @org, company_name: "Acme", contact_name: "Jane", active: true)
    @customer_user = CustomerUser.create!(organisation: @org, customer: @customer,
      email: "jane@acme.test", password: "password123", password_confirmation: "password123",
      contact_name: "Jane", active: true)
    @product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000, published: true)
    @order = Order.create!(customer: @customer, customer_user: @customer_user, organisation: @org)
  end

  test "refresh_pricing! drops an expired discount to zero" do
    discount = ProductDiscount.create!(organisation: @org, product: @product,
      discount_type: "percentage", discount_value: 0.10, min_quantity: 1, active: true)
    item = @order.order_items.create!(product: @product, quantity: 1)
    assert_equal 0.10, item.discount_percentage.to_f.round(4)

    discount.update!(valid_until: Date.yesterday)
    item.reload
    changes = item.refresh_pricing!

    assert_equal 0.0, item.discount_percentage.to_f
    assert changes.key?(:discount_percentage)
  end

  test "refresh_pricing! picks up a variant price change" do
    item = @order.order_items.create!(product: @product, quantity: 1)
    assert_equal 1000, item.unit_price

    @product.default_variant.update!(unit_price_cents: 1500)
    item.reload
    changes = item.refresh_pricing!

    assert_equal 1500, item.unit_price
    assert_equal [1000, 1500], changes[:unit_price]
  end

  test "refresh_pricing! applies a customer tier discount added after add-to-cart" do
    item = @order.order_items.create!(product: @product, quantity: 1)
    assert_equal 0.0, item.discount_percentage.to_f

    CustomerDiscount.create!(organisation: @org, customer: @customer,
      discount_type: "percentage", discount_value: 0.05, active: true)
    item.reload
    changes = item.refresh_pricing!

    assert_equal 0.05, item.discount_percentage.to_f.round(4)
    assert changes.key?(:discount_percentage)
  end

  test "refresh_pricing! returns empty hash when nothing changed" do
    item = @order.order_items.create!(product: @product, quantity: 1)
    item.reload
    assert_equal({}, item.refresh_pricing!)
  end

  test "refresh_pricing! is a no-op once the order is placed" do
    item = @order.order_items.create!(product: @product, quantity: 1)
    @order.update!(placed_at: Time.current)
    @product.default_variant.update!(unit_price_cents: 9999)
    item.reload

    assert_equal({}, item.refresh_pricing!)
    assert_equal 1000, item.unit_price
  end

  test "note is optional and persists" do
    item = @order.order_items.create!(product: @product, quantity: 1, note: "Entregar sem embalagem")
    assert_equal "Entregar sem embalagem", item.reload.note

    blank = @order.order_items.new(product: @product, quantity: 1)
    assert blank.valid?, "note should be optional"
  end

  test "note is rejected beyond 500 characters" do
    item = @order.order_items.new(product: @product, quantity: 1, note: "a" * 501)
    assert_not item.valid?
    assert_includes item.errors.attribute_names, :note
  end

  test "stock_status is purchasable when quantity fits the enforced stock" do
    @product.default_variant.update!(track_stock: true, stock_quantity: 10, stock_policy: "show_badge")
    item = @order.order_items.create!(product: @product, quantity: 3)
    item.reload
    assert_equal :purchasable, item.stock_status
  end

  test "stock_status flags qty_overflow when quantity exceeds enforced stock" do
    item = @order.order_items.create!(product: @product, quantity: 5)
    @product.default_variant.update!(track_stock: true, stock_quantity: 2, stock_policy: "show_badge")
    item.reload
    assert_equal :qty_overflow, item.stock_status
  end

  test "stock_status ignores qty overflow under track_only (backorder)" do
    item = @order.order_items.create!(product: @product, quantity: 5)
    @product.default_variant.update!(track_stock: true, stock_quantity: 2, stock_policy: "track_only")
    item.reload
    assert_equal :purchasable, item.stock_status
  end

  test "stock_status is out_of_stock when a tracked variant hits zero" do
    item = @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(track_stock: true, stock_quantity: 0, stock_policy: "show_badge")
    item.reload
    assert_equal :out_of_stock, item.stock_status
  end

  test "stock_status is variant_unpublished when the variant is unpublished" do
    item = @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(published: false)
    item.reload
    assert_equal :variant_unpublished, item.stock_status
  end

  test "rejects quantity below the product minimum on create" do
    @product.update!(min_quantity: 10)
    item = @order.order_items.build(product: @product, quantity: 5)
    assert_not item.valid?(:create)
    assert item.errors[:base].present?
  end

  test "accepts quantity at or above the product minimum on create" do
    @product.update!(min_quantity: 10)
    item = @order.order_items.build(product: @product, quantity: 10)
    assert item.valid?(:create)
  end

  test "does not enforce a minimum of 1 or less" do
    @product.update!(min_quantity: 1)
    item = @order.order_items.build(product: @product, quantity: 1)
    assert item.valid?(:create)
  end

  test "rejects a below-minimum quantity on a customer_change save" do
    @product.update!(min_quantity: 10)
    item = @order.order_items.create!(product: @product, quantity: 10)
    item.quantity = 4
    assert_not item.save(context: :customer_change)
    assert item.errors[:base].present?
  end

  test "does not enforce the minimum on a context-less save (system re-pricing)" do
    @product.update!(min_quantity: 10)
    item = @order.order_items.create!(product: @product, quantity: 10)
    # Simulate a stale below-minimum line, then a system save (no context)
    item.update_column(:quantity, 3)
    item.unit_price = 1234
    assert item.save, "system re-pricing must not be blocked by the minimum"
  end

  test "does not enforce a per-line minimum for combined-scope products" do
    product = Product.create!(organisation: @org, name: "Combo", published: true,
      has_variants: true, min_quantity: 12, min_quantity_scope: "combined")
    variant = product.product_variants.create!(name: "Red", sku: "CMB-R",
      unit_price_cents: 1000, published: true, is_default: false, track_stock: false)

    item = @order.order_items.build(product: product, product_variant: variant, quantity: 5)
    assert item.valid?(:create), "a single combined-scope line below the product min must be allowed"
  end

  test "waives the per-line minimum when stock can't reach it (no backorder)" do
    @org.update!(out_of_stock_strategy: "deactivate") # inherit -> show_badge, no backorder
    @product.update!(min_quantity: 10)
    @product.default_variant.update!(track_stock: true, stock_quantity: 5) # 5 < 10

    item = @order.order_items.build(product: @product, quantity: 5)
    assert item.valid?(:create), "minimum must be waived when stock (5) < min (10) and no backorder"
  end

  test "still enforces the per-line minimum when stock can reach it" do
    @org.update!(out_of_stock_strategy: "deactivate")
    @product.update!(min_quantity: 10)
    @product.default_variant.update!(track_stock: true, stock_quantity: 20) # 20 >= 10

    item = @order.order_items.build(product: @product, quantity: 5)
    assert_not item.valid?(:create), "minimum still applies when stock can reach it"
  end
end
