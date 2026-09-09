require "test_helper"

# Adding a line to an order used to mean finding it by name in a dropdown of
# every product in the organisation. With 45 products called "Moldura Criança"
# in the real catalog that is not a workable way to pick anything, so a line is
# now a variant, found by SKU.
class Bo::OrderLinePickerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @organisation = Organisation.create!(name: "Order Picker Org", currency: "EUR")
    @admin = Member.create!(email: "order-admin@example.com", password: "password123",
                            first_name: "Ana", last_name: "Admin")
    @organisation.org_members.create!(member: @admin, role: "owner", active: true)
    sign_in @admin

    @customer = @organisation.customers.create!(company_name: "Cliente Teste", contact_name: "Rui", active: true)
    @product = @organisation.products.create!(name: "Moldura Criança", unit_price: 1000, published: true)
    @variant = @product.default_variant
    # A default variant starts tracked with nothing in stock, which would put an
    # "out of stock" warning on every result; give it stock so each test says
    # what it is actually about.
    @variant.update!(sku: "MC-001", unit_price_cents: 1000, track_stock: true, stock_quantity: 5)
  end

  def search(query)
    get variant_search_bo_orders_path(org_slug: @organisation.slug, query: query)
    JSON.parse(response.body)
  end

  test "finds a line by its SKU" do
    results = search("MC-001")

    assert_response :success
    assert_equal [ @variant.id ], results.map { |r| r["value"] }
    assert_equal "MC-001", results.first["sku"]
  end

  test "finds a line by product name" do
    assert_equal [ @variant.id ], search("Moldura").map { |r| r["value"] }
  end

  test "ignores accents in the search" do
    assert_equal [ @variant.id ], search("crianca").map { |r| r["value"] }
  end

  # Two products can share a name; their SKUs are what tell them apart, which is
  # the whole reason for picking by variant.
  test "tells apart two products with the same name" do
    twin = @organisation.products.create!(name: "Moldura Criança", unit_price: 2000, published: true)
    twin.default_variant.update!(sku: "MC-002")

    by_name = search("Moldura Criança")
    assert_equal 2, by_name.size

    by_sku = search("MC-002")
    assert_equal [ twin.default_variant.id ], by_sku.map { |r| r["value"] }
  end

  # The base variant of a variable product is a placeholder, not something that
  # can be sold, so it must never be offered as a line.
  test "never offers the placeholder variant of a variable product" do
    variable = @organisation.products.create!(name: "Anel Variável", unit_price: 500, published: true)
    variable.update!(has_variants: true)
    variable.default_variant.update_columns(sku: "PLACEHOLDER-1")

    assert_empty search("PLACEHOLDER-1")
  end

  # The back office may sell what the shop cannot — a restock on its way, an
  # item still unpublished — but never without seeing what it is choosing.
  test "shows how much stock a line has" do
    @variant.update!(track_stock: true, stock_quantity: 12)

    assert_equal I18n.t("bo.orders.form.picker_stock", count: 12), search("MC-001").first["stock"]
  end

  test "says so when stock is not tracked" do
    @variant.update!(track_stock: false)

    assert_equal I18n.t("bo.orders.form.picker_no_stock_control"), search("MC-001").first["stock"]
    assert_nil search("MC-001").first["warning"]
  end

  test "warns about a line with no stock" do
    @variant.update!(track_stock: true, stock_quantity: 0)

    assert_equal I18n.t("bo.orders.form.picker_out_of_stock"), search("MC-001").first["warning"]
  end

  test "warns about a line the shop does not show" do
    @variant.update!(published: false)

    assert_equal I18n.t("bo.orders.form.picker_unpublished"), search("MC-001").first["warning"]
  end

  test "warns about both at once" do
    @variant.update!(track_stock: true, stock_quantity: 0, published: false)

    assert_equal "#{I18n.t("bo.orders.form.picker_out_of_stock")} · #{I18n.t("bo.orders.form.picker_unpublished")}", search("MC-001").first["warning"]
  end

  # The warning is the whole point: it is offered anyway.
  test "still offers a line the shop could not sell" do
    @variant.update!(track_stock: true, stock_quantity: 0, published: false)

    assert_equal [ @variant.id ], search("MC-001").map { |r| r["value"] }
  end

  test "an empty query returns nothing rather than the catalog" do
    get variant_search_bo_orders_path(org_slug: @organisation.slug)

    assert_response :success
    assert_empty JSON.parse(response.body)
  end

  test "quotes the price and the customer's discount for a chosen line" do
    CustomerDiscount.create!(organisation: @organisation, customer: @customer,
                             discount_type: "percentage", discount_value: 0.10,
                             active: true, stackable: false)

    get variant_pricing_bo_orders_path(org_slug: @organisation.slug,
                                       variant_id: @variant.id, customer_id: @customer.id)

    assert_response :success
    pricing = JSON.parse(response.body)
    assert_equal @product.id, pricing["product_id"]
    assert_equal 10.0, pricing["unit_price"]
    assert_equal 0.1, pricing["discount_percentage"]
  end

  test "quotes without a customer for an order that has none yet" do
    get variant_pricing_bo_orders_path(org_slug: @organisation.slug, variant_id: @variant.id)

    assert_response :success
    pricing = JSON.parse(response.body)
    assert_equal 10.0, pricing["unit_price"]
    assert_equal 0, pricing["discount_percentage"]
  end

  # The new-order screen shares the same partials, and used to carry its own
  # copy of the row markup — so only one of the two ever got fixed.
  test "the new order screen renders the same picker" do
    30.times { |i| @organisation.products.create!(name: "Outro #{i}", unit_price: 100, published: true) }

    get new_bo_order_path(org_slug: @organisation.slug)

    assert_response :success
    assert_select "select[name*='product_variant_id']", minimum: 1
    assert_no_match(/Outro 1</, response.body)
  end

  test "the order pages no longer carry the catalog" do
    login = @customer.customer_users.create!(organisation: @organisation, contact_name: "Rui", email: "rui-#{SecureRandom.hex(3)}@exemplo.pt", password: "password123")
    order = @organisation.orders.create!(customer: @customer, customer_user: login,
                                         status: "in_process", placed_at: Time.current)
    30.times { |i| @organisation.products.create!(name: "Outro #{i}", unit_price: 100, published: true) }

    order.order_items.create!(product: @product, product_variant: @variant, quantity: 1, unit_price: 1000)

    get edit_bo_order_path(org_slug: @organisation.slug, id: order.id)

    assert_response :success
    # The line carries its own variant and nothing else: 30 other products exist
    # and none of them is in the markup. The rest arrive by search.
    options = css_select("select[name*='product_variant_id'] option")
    assert_operator options.size, :<=, 2, "the picker should carry the prompt and the chosen variant only"
    assert_no_match(/Outro 1</, response.body)
  end

  # Saving a line: it follows the shop's rules by default, and anything typed in
  # the back office wins over them.
  def order_with_line(discount: nil)
    login = @customer.customer_users.create!(organisation: @organisation, contact_name: "Rui",
                                             email: "rui-#{SecureRandom.hex(3)}@exemplo.pt", password: "password123")
    order = @organisation.orders.create!(customer: @customer, customer_user: login,
                                         status: "in_process", placed_at: Time.current)
    order
  end

  def add_line(order, attrs)
    patch bo_order_path(org_slug: @organisation.slug, id: order.id),
          params: { order: { order_items_attributes: { "0" => attrs } } }
    order.reload.order_items.last
  end

  test "a line saved from the picker knows its product" do
    order = order_with_line

    line = add_line(order, { product_variant_id: @variant.id, quantity: "2", price: "10.00" })

    assert_equal @variant.id, line.product_variant_id
    assert_equal @product.id, line.product_id, "the product comes from the variant, not the form"
  end

  # The product is derived server-side, so a wrong or missing hidden field
  # cannot produce a line whose product and variant disagree.
  test "a wrong product on the form does not corrupt the line" do
    other = @organisation.products.create!(name: "Outro Produto", unit_price: 500, published: true)
    order = order_with_line

    line = add_line(order, { product_variant_id: @variant.id, product_id: other.id, quantity: "1", price: "10.00" })

    assert_equal @product.id, line.product_id
  end

  test "left blank, the discount follows the customer's rules" do
    CustomerDiscount.create!(organisation: @organisation, customer: @customer,
                             discount_type: "percentage", discount_value: 0.10,
                             active: true, stackable: false)
    order = order_with_line

    line = add_line(order, { product_variant_id: @variant.id, quantity: "1", price: "10.00", discount_percent: "" })

    assert_equal 0.1, line.discount_percentage.to_f
  end

  # The whole reason the field is editable: correcting a bad discount, or
  # granting one. What the back office types must survive the save.
  test "a discount typed in the back office is not overwritten" do
    CustomerDiscount.create!(organisation: @organisation, customer: @customer,
                             discount_type: "percentage", discount_value: 0.10,
                             active: true, stackable: false)
    order = order_with_line

    line = add_line(order, { product_variant_id: @variant.id, quantity: "1", price: "10.00", discount_percent: "25" })

    assert_equal 0.25, line.discount_percentage.to_f
  end

  test "a discount is stored as a fraction of the percentage typed" do
    order = order_with_line

    line = add_line(order, { product_variant_id: @variant.id, quantity: "1", price: "10.00", discount_percent: "7.5" })

    assert_equal 0.075, line.discount_percentage.to_f
    assert_equal 7.5, line.discount_percent
  end

  test "the line total accounts for the discount" do
    order = order_with_line

    line = add_line(order, { product_variant_id: @variant.id, quantity: "2", price: "10.00", discount_percent: "50" })

    assert_equal 10.0, line.total_price.to_f
  end
end
