require "test_helper"

class OrderTest < ActiveSupport::TestCase
  def setup
    @org = Organisation.create!(name: "Order Refresh Org")
    @customer = Customer.create!(organisation: @org, company_name: "Acme", contact_name: "Jane", active: true)
    @customer_user = CustomerUser.create!(organisation: @org, customer: @customer,
      email: "jane@acme.test", password: "password123", password_confirmation: "password123",
      contact_name: "Jane", active: true)
    @product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000, published: true)
    @order = Order.create!(customer: @customer, customer_user: @customer_user, organisation: @org)
  end

  test "refresh_cart! persists changed line items and reports the deltas" do
    item = @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(unit_price_cents: 1500)
    @order.reload

    changes = @order.refresh_cart!

    assert_equal [item.id], changes[:price_changed]
    assert_equal 1500, item.reload.unit_price
  end

  test "refresh_cart! is a no-op for placed orders" do
    item = @order.order_items.create!(product: @product, quantity: 1)
    @order.update!(placed_at: Time.current)
    @product.default_variant.update!(unit_price_cents: 1500)
    @order.reload

    changes = @order.refresh_cart!

    assert_equal [], changes[:price_changed]
    assert_equal 1000, item.reload.unit_price
  end

  test "finalize_checkout! snapshots fresh line pricing before placing" do
    item = @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(unit_price_cents: 2000)
    @order.reload
    @order.terms_accepted_at = Time.current

    @order.finalize_checkout!

    assert @order.placed?
    assert_equal 2000, item.reload.unit_price
  end

  test "refresh_cart! removes out-of-stock items under the remove policy" do
    @org.update!(cart_stock_policy: "remove")
    item = @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(track_stock: true, stock_quantity: 0, stock_policy: "show_badge")
    @order.reload

    changes = @order.refresh_cart!

    assert_equal 1, changes[:removed].size
    assert_not OrderItem.exists?(item.id)
  end

  test "refresh_cart! keeps and records out-of-stock items under the warn policy" do
    item = @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(track_stock: true, stock_quantity: 0, stock_policy: "show_badge")
    @order.reload

    changes = @order.refresh_cart!

    assert OrderItem.exists?(item.id)
    assert_equal 1, changes[:out_of_stock].size
  end

  test "refresh_cart! caps quantity to available stock under the cap policy" do
    @org.update!(cart_qty_overflow_policy: "cap")
    item = @order.order_items.create!(product: @product, quantity: 5)
    @product.default_variant.update!(track_stock: true, stock_quantity: 2, stock_policy: "show_badge")
    @order.reload

    changes = @order.refresh_cart!

    assert_equal 2, item.reload.quantity
    assert_equal 2, changes[:capped].first[:to]
  end

  test "refresh_cart! warns on qty overflow without changing quantity by default" do
    item = @order.order_items.create!(product: @product, quantity: 5)
    @product.default_variant.update!(track_stock: true, stock_quantity: 2, stock_policy: "show_badge")
    @order.reload

    changes = @order.refresh_cart!

    assert_equal 5, item.reload.quantity
    assert_equal 2, changes[:qty_overflow].first[:available]
  end

  test "finalize_checkout! blocks placing with out-of-stock items under block policy" do
    @org.update!(checkout_stock_policy: "block")
    @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(track_stock: true, stock_quantity: 0, stock_policy: "show_badge")
    @order.reload
    @order.terms_accepted_at = Time.current

    assert_raises(ActiveRecord::RecordInvalid) { @order.finalize_checkout! }
    assert_not @order.reload.placed?
  end

  test "finalize_checkout! requires confirmation for out-of-stock items under warn policy" do
    # default checkout_stock_policy is "warn"
    @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(track_stock: true, stock_quantity: 0, stock_policy: "show_badge")
    @order.reload
    @order.terms_accepted_at = Time.current

    assert_raises(ActiveRecord::RecordInvalid) { @order.finalize_checkout! }
    assert_not @order.reload.placed?
  end

  test "finalize_checkout! places under warn policy once confirmed" do
    @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(track_stock: true, stock_quantity: 0, stock_policy: "show_badge")
    @order.reload
    @order.terms_accepted_at = Time.current
    @order.confirmed_stock_warnings = "1"

    @order.finalize_checkout!

    assert @order.placed?
  end

  test "finalize_checkout! places out-of-stock items under allow policy" do
    @org.update!(checkout_stock_policy: "allow")
    @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(track_stock: true, stock_quantity: 0, stock_policy: "show_badge")
    @order.reload
    @order.terms_accepted_at = Time.current

    @order.finalize_checkout!

    assert @order.placed?
  end

  test "refresh_cart! flags a pending pricing change under the confirm policy" do
    @org.update!(cart_price_change_policy: "confirm")
    @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(unit_price_cents: 1500)
    @order.reload

    @order.refresh_cart!

    assert @order.reload.pricing_change_pending?
  end

  test "refresh_cart! does not flag a pending pricing change under notify" do
    # default cart_price_change_policy is "notify"
    @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(unit_price_cents: 1500)
    @order.reload

    @order.refresh_cart!

    assert_not @order.reload.pricing_change_pending?
  end

  test "acknowledge_pricing_change! clears the pending flag" do
    @order.update_column(:pricing_changed_at, Time.current)
    @order.acknowledge_pricing_change!
    assert_not @order.reload.pricing_change_pending?
  end

  test "finalize_checkout! blocks under confirm until the pricing change is acknowledged" do
    @org.update!(cart_price_change_policy: "confirm")
    @order.order_items.create!(product: @product, quantity: 1)
    @product.default_variant.update!(unit_price_cents: 1500)
    @order.reload
    @order.terms_accepted_at = Time.current

    assert_raises(ActiveRecord::RecordInvalid) { @order.finalize_checkout! }
    assert_not @order.reload.placed?

    @order.acknowledge_pricing_change!
    @order.terms_accepted_at = Time.current
    @order.finalize_checkout!

    assert @order.placed?
  end

  test "finalize_checkout! blocks when a line is below the product minimum" do
    @product.update!(min_quantity: 12)
    item = @order.order_items.create!(product: @product, quantity: 12)
    # Simulate a legacy/grid-built line that dropped below the minimum
    item.update_column(:quantity, 3)
    @order.reload
    @order.terms_accepted_at = Time.current

    assert_raises(ActiveRecord::RecordInvalid) { @order.finalize_checkout! }
    assert_not @order.reload.placed?

    item.update_column(:quantity, 12)
    @order.reload
    @order.terms_accepted_at = Time.current
    @order.finalize_checkout!

    assert @order.placed?
  end

  test "max discount cap limits an order-level discount that exceeds it" do
    @org.update!(max_discount_percentage: 0.30) # never more than 30% off
    @order.order_items.create!(product: @product, quantity: 100) # €1000 gross
    OrderDiscount.create!(organisation: @org, discount_type: "percentage", discount_value: 0.50,
      min_order_amount_cents: 100, active: true) # 50% alone exceeds 30%

    assert_equal Money.new(100_000, "EUR"), @order.gross_subtotal
    assert @order.discount_capped?
    assert_equal Money.new(70_000, "EUR"), @order.subtotal_after_discount # capped to 30% off
  end

  test "max discount cap counts line-level discounts toward the total" do
    @org.update!(max_discount_percentage: 0.20) # max 20%
    CustomerDiscount.create!(organisation: @org, customer: @customer,
      discount_type: "percentage", discount_value: 0.25, active: true) # 25% line alone > 20%
    @order.order_items.create!(product: @product, quantity: 100) # gross €1000, line -25% -> €750

    assert_equal Money.new(100_000, "EUR"), @order.gross_subtotal
    assert @order.discount_capped?
    assert_equal Money.new(80_000, "EUR"), @order.subtotal_after_discount # capped to 20% off €1000
  end

  test "max discount cap leaves orders below the cap untouched" do
    @org.update!(max_discount_percentage: 0.30)
    @order.order_items.create!(product: @product, quantity: 100)
    OrderDiscount.create!(organisation: @org, discount_type: "percentage", discount_value: 0.10,
      min_order_amount_cents: 100, active: true)

    assert_not @order.discount_capped?
    assert_equal Money.new(90_000, "EUR"), @order.subtotal_after_discount
  end

  test "order-level discounts compound, each on the already-discounted total" do
    @order.order_items.create!(product: @product, quantity: 100) # €1000 line total
    OrderDiscount.create!(organisation: @org, discount_type: "percentage", discount_value: 0.10,
      min_order_amount_cents: 100, active: true)
    promo = PromoCode.create!(organisation: @org, code: "TEST10", discount_type: "percentage",
      discount_value: 0.10, eligibility: "all_customers", active: true)

    @order.promo_code = promo
    @order.discount_type = "percentage"
    @order.discount_value = 0.10

    assert_equal Money.new(100_000, "EUR"), @order.total_amount
    assert_equal Money.new(90_000, "EUR"), @order.total_with_auto_discount # gross -10% tier
    assert_equal Money.new(9_000, "EUR"), @order.promo_code_discount       # 10% of 900
    assert_equal Money.new(8_100, "EUR"), @order.order_discount_amount     # 10% of (900-90)=810
    assert_equal Money.new(72_900, "EUR"), @order.subtotal_after_discount  # 729, fully compound
  end

  test "combined-scope minimum is met by the sum of the product's variant lines" do
    product = Product.create!(organisation: @org, name: "Combo", published: true,
      has_variants: true, min_quantity: 12, min_quantity_scope: "combined")
    red = product.product_variants.create!(name: "Red", sku: "CMB-R",
      unit_price_cents: 1000, published: true, is_default: false, track_stock: false)
    blue = product.product_variants.create!(name: "Blue", sku: "CMB-B",
      unit_price_cents: 1000, published: true, is_default: false, track_stock: false)

    @order.order_items.create!(product: product, product_variant: red, quantity: 5)
    @order.order_items.create!(product: product, product_variant: blue, quantity: 4)

    shortfalls = @order.combined_min_quantity_shortfalls
    assert_equal 1, shortfalls.size
    assert_equal 9, shortfalls.first[:current]
    assert_equal 3, shortfalls.first[:shortfall]

    @order.terms_accepted_at = Time.current
    assert_raises(ActiveRecord::RecordInvalid) { @order.finalize_checkout! }
    assert_not @order.reload.placed?

    # Bump the blue line so the combined total reaches 12
    @order.order_items.find_by(product_variant: blue).update_column(:quantity, 7)
    assert_empty @order.combined_min_quantity_shortfalls

    @order.terms_accepted_at = Time.current
    @order.finalize_checkout!
    assert @order.placed?
  end

  test "combined minimum is waived when total stock can't reach it (no backorder)" do
    @org.update!(out_of_stock_strategy: "deactivate") # no backorder
    product = Product.create!(organisation: @org, name: "Combo2", published: true,
      has_variants: true, min_quantity: 30, min_quantity_scope: "combined")
    red = product.product_variants.create!(name: "Red", sku: "C2R",
      unit_price_cents: 1000, published: true, is_default: false, track_stock: true, stock_quantity: 5)
    blue = product.product_variants.create!(name: "Blue", sku: "C2B",
      unit_price_cents: 1000, published: true, is_default: false, track_stock: true, stock_quantity: 4)

    @order.order_items.create!(product: product, product_variant: red, quantity: 5)
    @order.order_items.create!(product: product, product_variant: blue, quantity: 4)

    # Total sellable stock is 9, far below the min of 30, and no backorder ->
    # the minimum is waived, so checkout is not blocked (no dead-end).
    assert_empty @order.combined_min_quantity_shortfalls
    @order.terms_accepted_at = Time.current
    @order.finalize_checkout!
    assert @order.placed?
  end
end
