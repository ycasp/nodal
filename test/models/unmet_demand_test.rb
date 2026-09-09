require "test_helper"

class UnmetDemandTest < ActiveSupport::TestCase
  def setup
    @org = Organisation.create!(name: "Unmet Demand Org")
    @customer = Customer.create!(organisation: @org, company_name: "Acme", contact_name: "Jane", active: true)
    @customer_user = CustomerUser.create!(organisation: @org, customer: @customer,
      email: "jane@acme.test", password: "password123", password_confirmation: "password123",
      contact_name: "Jane", active: true)
    @product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000, published: true)
    @member = Member.create!(email: "owner@acme.test", password: "password123", password_confirmation: "password123",
      first_name: "Owner", last_name: "Member")
    @order = Order.create!(customer: @customer, customer_user: @customer_user, organisation: @org)
  end

  def build_demand(**attrs)
    UnmetDemand.create!({
      organisation: @org, customer: @customer, customer_user: @customer_user, product: @product,
      product_variant: @product.default_variant, requested_quantity: 10, reason: "capped",
      first_seen_at: Time.current, last_seen_at: Time.current
    }.merge(attrs))
  end

  # --- Capture from cart stock policies ---

  test "capping a line records the original requested quantity, keyed by login" do
    @org.update!(cart_qty_overflow_policy: "cap")
    @product.default_variant.update!(track_stock: true, stock_quantity: 2, stock_policy: "show_badge")
    @order.order_items.create!(product: @product, quantity: 10)
    @order.reload

    @order.refresh_cart!

    demand = UnmetDemand.open.find_by(customer_user: @customer_user, product: @product)
    assert demand, "expected an open demand to be recorded"
    assert_equal @customer_user.id, demand.customer_user_id
    assert_equal @customer.id, demand.customer_id
    assert_equal 10, demand.requested_quantity
    assert_equal 10, demand.shortfall
    assert_equal "capped", demand.reason
  end

  test "each cut appends an immutable occurrence preserving the history" do
    @org.update!(cart_qty_overflow_policy: "cap")
    @product.default_variant.update!(track_stock: true, stock_quantity: 2, stock_policy: "show_badge")
    @order.order_items.create!(product: @product, quantity: 10)
    @order.reload
    @order.refresh_cart!

    occ = UnmetDemandOccurrence.find_by(customer_user: @customer_user, product: @product)
    assert occ, "expected an occurrence row"
    assert_equal 10, occ.requested_quantity
    assert_equal 2, occ.kept_quantity
    assert_equal 8, occ.short_quantity
    assert_equal "capped", occ.reason
  end

  test "removing an out-of-stock line records the requested quantity and a kept=0 occurrence" do
    @org.update!(cart_stock_policy: "remove")
    @order.order_items.create!(product: @product, quantity: 7)
    @product.default_variant.update!(track_stock: true, stock_quantity: 0, stock_policy: "show_badge")
    @order.reload

    @order.refresh_cart!

    demand = UnmetDemand.open.find_by(customer_user: @customer_user, product: @product)
    assert_equal 7, demand.requested_quantity
    assert_equal "removed", demand.reason
    occ = demand.occurrences.first
    assert_equal 0, occ.kept_quantity
    assert_equal "removed", occ.reason
  end

  test "repeated cart refreshes keep one open row but log every occurrence (decision 1a)" do
    @org.update!(cart_qty_overflow_policy: "cap")
    @product.default_variant.update!(track_stock: true, stock_quantity: 2, stock_policy: "show_badge")
    @order.order_items.create!(product: @product, quantity: 10)
    @order.reload
    @order.refresh_cart!

    @order.order_items.first.update!(quantity: 25)
    @order.reload
    @order.refresh_cart!

    demands = UnmetDemand.where(customer_user: @customer_user, product: @product)
    assert_equal 1, demands.count, "should not pile up aggregate rows"
    assert_equal 25, demands.first.requested_quantity, "should keep the largest requested qty"
    assert_equal 2, demands.first.occurrences.count, "but every occurrence is logged"
  end

  # --- Auto-close on placement (decision 4) ---

  test "placing an order abates the demand and closes it once fully met" do
    demand = build_demand(requested_quantity: 10)

    @product.default_variant.update!(track_stock: false)
    @order.order_items.create!(product: @product, quantity: 4)
    @order.place!

    demand.reload
    assert demand.open?, "partial fulfilment should leave it open"
    assert_equal 4, demand.fulfilled_quantity
    assert_equal 6, demand.shortfall

    order2 = Order.create!(customer: @customer, customer_user: @customer_user, organisation: @org)
    order2.order_items.create!(product: @product, quantity: 6)
    order2.place!

    demand.reload
    assert_equal "resolved", demand.status
    assert_equal "customer_self_served", demand.resolution
  end

  test "another login's placement does not close this login's demand" do
    other_user = CustomerUser.create!(organisation: @org, customer: @customer,
      email: "bob@acme.test", password: "password123", password_confirmation: "password123",
      contact_name: "Bob", active: true)
    demand = build_demand(requested_quantity: 10)

    @product.default_variant.update!(track_stock: false)
    other_order = Order.create!(customer: @customer, customer_user: other_user, organisation: @org)
    other_order.order_items.create!(product: @product, quantity: 10)
    other_order.place!

    assert demand.reload.open?, "demand belongs to Jane's cart; Bob's order shouldn't resolve it"
  end

  # --- "In cart" visibility ---

  test "quantity_in_cart reflects the login's open draft for the product" do
    @order.order_items.create!(product: @product, quantity: 6)
    demand = build_demand(requested_quantity: 50)
    assert_equal 6, demand.quantity_in_cart
  end

  # --- BO satisfy action (decision 3b) ---

  test "satisfy! drafts into the login's own cart and resolves the demand" do
    demand = build_demand(requested_quantity: 12, fulfilled_quantity: 2)

    draft = demand.satisfy!(member: @member)

    assert draft.draft?, "generated order should be a draft cart"
    assert_equal @customer_user.id, draft.customer_user_id, "should target the login that hit the shortfall"
    assert_equal 10, draft.order_items.where(product: @product).sum(:quantity), "should draft the shortfall"
    demand.reload
    assert_equal "resolved", demand.status
    assert_equal "draft_generated", demand.resolution
    assert_equal draft.id, demand.order_id
  end

  # --- BO substitute action ("Trocar") ---

  test "satisfy! with a substitute variant drafts that variant and records the product" do
    substitute = Product.create!(organisation: @org, name: "Alt Widget", unit_price: 900, published: true)
    substitute_variant = substitute.default_variant
    demand = build_demand(requested_quantity: 8)

    draft = demand.satisfy!(member: @member, substitute_variant: substitute_variant)

    assert_equal 8, draft.order_items.where(product_variant: substitute_variant).sum(:quantity)
    assert_equal 0, draft.order_items.where(product: @product).sum(:quantity)
    demand.reload
    assert_equal "substituted", demand.resolution
    assert_equal substitute.id, demand.substitute_product_id
  end

  test "dismiss! closes the demand without an order" do
    demand = build_demand(requested_quantity: 5, reason: "removed")

    demand.dismiss!(member: @member)

    demand.reload
    assert_equal "dismissed", demand.status
    assert_equal "dismissed", demand.resolution
    assert_nil demand.order_id
  end

  test "shortfall never goes negative" do
    demand = UnmetDemand.new(requested_quantity: 3, fulfilled_quantity: 10)
    assert_equal 0, demand.shortfall
  end
end
