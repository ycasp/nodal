require "test_helper"
require "minitest/mock"

# Covers per-line cart notes: a customer can attach an observation to a cart
# line via #update, it persists, and it renders on the cart and checkout pages.
class Storefront::OrderItemsNoteTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = Organisation.create!(name: "Note Org", currency: "EUR",
                                email_order_confirmation_enabled: true)
    @customer = @org.customers.create!(company_name: "Cliente Lda", contact_name: "João",
                                       email: "cli@example.com", active: true)
    @customer_user = CustomerUser.create!(
      email: "buyer@example.com", password: "password123",
      organisation: @org, customer: @customer, active: true,
      invitation_accepted_at: Time.current
    )
    @product = Product.create!(organisation: @org, name: "Camisa", sku: "CAM-001",
                               unit_price: 1999, published: true, available: true)
    sign_in @customer_user
  end

  def cart
    @customer_user.orders.draft.find_by(organisation: @org)
  end

  def add_item
    post order_items_path(org_slug: @org.slug),
         params: { product_id: @product.id, order_item: { quantity: 1 } }
    cart.order_items.find_by(product: @product)
  end

  test "updating a line saves its note" do
    item = add_item
    patch order_item_path(org_slug: @org.slug, id: item),
          params: { order_item: { note: "Entregar sem embalagem" } }
    assert_redirected_to cart_path(org_slug: @org.slug)
    assert_equal "Entregar sem embalagem", item.reload.note
  end

  test "the note renders on the cart and checkout pages" do
    item = add_item
    item.update!(note: "Cor à escolha do cliente")

    get cart_path(org_slug: @org.slug)
    assert_response :success
    assert_includes @response.body, "Cor à escolha do cliente"

    get checkout_path(org_slug: @org.slug)
    assert_response :success
    assert_includes @response.body, "Cor à escolha do cliente"
  end

  test "a note over 500 chars is rejected with an alert" do
    item = add_item
    patch order_item_path(org_slug: @org.slug, id: item),
          params: { order_item: { note: "a" * 501 } }
    assert_redirected_to cart_path(org_slug: @org.slug)
    assert_nil item.reload.note
  end

  test "the note renders on the customer order show page" do
    order = Order.create!(organisation: @org, customer: @customer, customer_user: @customer_user,
                          placed_at: Time.current)
    order.order_items.create!(product: @product, quantity: 2, note: "Entregar à tarde")

    get order_path(org_slug: @org.slug, id: order)
    assert_response :success
    assert_includes @response.body, "Entregar à tarde"
  end

  test "the note renders in the customer confirmation email (html and text)" do
    order = Order.create!(organisation: @org, customer: @customer, customer_user: @customer_user,
                          placed_at: Time.current)
    order.order_items.create!(product: @product, quantity: 1, note: "Embrulhar para oferta")

    mail = CustomerMailer.with(customer_user: @customer_user, order: order).confirm_order
    body = mail.body.encoded
    assert_includes body, "Embrulhar para oferta"
  end

  test "the note renders in the order PDF template" do
    order = Order.create!(organisation: @org, customer: @customer, customer_user: @customer_user,
                          placed_at: Time.current)
    order.order_items.create!(product: @product, quantity: 1, note: "Marcar com etiqueta frágil")

    # Capture the HTML the controller renders before Grover turns it into a PDF,
    # so we exercise the template without needing headless Chrome in the suite.
    captured = nil
    fake = Object.new
    def fake.to_pdf = "%PDF-1.4"
    Grover.stub :new, ->(html) { captured = html; fake } do
      get download_pdf_order_path(org_slug: @org.slug, id: order)
    end

    assert_response :success
    assert_includes captured, "Marcar com etiqueta frágil"
  end
end
