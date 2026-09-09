require "application_system_test_case"

# The picker is a Tom Select fed by the server and a fetch that fills in the
# price and discount. None of that exists outside a browser, and the request
# tests pass whether or not the wiring works.
class OrderLinePickerTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  include Warden::Test::Helpers

  setup do
    Warden.test_mode!

    @organisation = Organisation.create!(name: "Order Picker Org", currency: "EUR")
    @admin = Member.create!(email: "order-sys-admin@example.com", password: "password123",
                            first_name: "Ana", last_name: "Admin")
    @organisation.org_members.create!(member: @admin, role: "owner", active: true)

    @customer = @organisation.customers.create!(company_name: "Cliente Teste", contact_name: "Rui", active: true)
    @login = @customer.customer_users.create!(organisation: @organisation, contact_name: "Rui",
                                              email: "rui-sys@exemplo.pt", password: "password123")

    @product = @organisation.products.create!(name: "Moldura Criança", unit_price: 1000, published: true)
    @variant = @product.default_variant
    @variant.update!(sku: "MC-001", unit_price_cents: 1000)

    # A namesake, so the SKU is the only thing that tells them apart.
    twin = @organisation.products.create!(name: "Moldura Criança", unit_price: 5000, published: true)
    @twin_variant = twin.default_variant
    @twin_variant.update!(sku: "MC-999", unit_price_cents: 5000)

    @order = @organisation.orders.create!(customer: @customer, customer_user: @login,
                                          status: "in_process", placed_at: Time.current)

    login_as @admin, scope: :member
  end

  teardown { Warden.test_reset! }

  def visit_editor
    visit edit_bo_order_path(org_slug: @organisation.slug, id: @order.id)
    assert_selector "[data-order-items-target='container']", wait: 5
  end

  # The price, discount and total are all filled by JavaScript — one of them
  # after a round trip to the server — so comparing them needs to wait the way
  # Capybara's own matchers do. A plain assert_equal here just races.
  def assert_eventually(expected, message = nil)
    deadline = Time.now + Capybara.default_max_wait_time
    actual = nil

    loop do
      actual = yield
      break if actual == expected || Time.now > deadline
      sleep 0.1
    end

    assert_equal expected, actual, message
  end

  def add_line_and_pick(sku)
    click_on I18n.t("bo.orders.form.add_item")
    within all("[data-order-items-target='container'] tr").last do
      find(".ts-control").click
      find(".ts-control input", visible: :all).send_keys(sku)
      assert_selector ".ts-dropdown .option", text: sku, wait: 5
      find(".ts-dropdown .option", text: sku).click
      # The price arrives from the server. Typing before it lands is a race the
      # test should not be running — and the person editing should not lose
      # what they typed either, which is why the fill skips touched fields.
      assert_eventually(true) { find("[data-price-field]").value.present? }
    end
  end

  # The point of the whole change: 45 products can share a name, so the SKU has
  # to be what finds the line.
  test "adds a line by typing its SKU" do
    visit_editor

    add_line_and_pick("MC-999")

    within all("[data-order-items-target='container'] tr").last do
      assert_eventually("50.00") { find("[data-price-field]").value }
    end
  end

  test "picking a line fills the price the shop would charge" do
    visit_editor

    add_line_and_pick("MC-001")

    within all("[data-order-items-target='container'] tr").last do
      assert_eventually("10.00") { find("[data-price-field]").value }
    end
  end

  test "picking a line fills the customer's discount" do
    CustomerDiscount.create!(organisation: @organisation, customer: @customer,
                             discount_type: "percentage", discount_value: 0.10,
                             active: true, stackable: false)
    visit_editor

    add_line_and_pick("MC-001")

    within all("[data-order-items-target='container'] tr").last do
      assert_eventually("10.00") { find("[data-discount-field]").value }
    end
  end

  # The figure on screen used to be quantity x price, while the figure saved
  # subtracted the discount. They have to agree.
  test "the line total on screen includes the discount" do
    visit_editor
    add_line_and_pick("MC-001")

    within all("[data-order-items-target='container'] tr").last do
      find("[data-quantity-field]").fill_in with: "2"
      find("[data-discount-field]").fill_in with: "50"
      assert_eventually("10.00") { find("[data-line-total]").text }
    end
  end

  test "the line saves with what was picked and typed" do
    visit_editor
    add_line_and_pick("MC-001")

    within all("[data-order-items-target='container'] tr").last do
      find("[data-quantity-field]").fill_in with: "3"
      find("[data-discount-field]").fill_in with: "20"
    end
    click_on I18n.t("bo.common.actions.save")

    assert_no_selector "[data-order-items-target='container']", wait: 5
    line = @order.reload.order_items.last
    assert_equal @variant.id, line.product_variant_id
    assert_equal @product.id, line.product_id
    assert_equal 3, line.quantity
    assert_equal 0.2, line.discount_percentage.to_f
  end
end
