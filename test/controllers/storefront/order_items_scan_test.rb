require "test_helper"

# Covers scan-to-cart: a scanned barcode (variant SKU) resolves to a variant and
# adds/increments a cart line. Signed in as a normal CustomerUser (the endpoint
# is cart-owner scoped; impersonation only changes which cart is used + UI).
class Storefront::OrderItemsScanTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @org = Organisation.create!(name: "Scan Org", currency: "EUR")
    @customer = @org.customers.create!(company_name: "Cliente Lda", contact_name: "João",
                                       email: "cli@example.com", active: true)
    @customer_user = CustomerUser.create!(
      email: "buyer@example.com", password: "password123",
      organisation: @org, customer: @customer, active: true
    )

    @product = Product.create!(organisation: @org, name: "Camisa", sku: "CAM-001",
                               published: true, available: true)
    @variant = @product.product_variants.create!(
      organisation: @org, name: "Azul / M", sku: "CAM-001-AZ-M",
      unit_price_cents: 1999, unit_price_currency: "EUR",
      published: true, available: true, is_default: false
    )

    sign_in @customer_user
  end

  def cart
    @customer_user.orders.draft.find_by(organisation: @org)
  end

  test "scanning a known variant SKU adds it to the cart" do
    post scan_order_items_path(org_slug: @org.slug), params: { code: "CAM-001-AZ-M" }
    assert_redirected_to cart_path(org_slug: @org.slug)

    item = cart.order_items.find_by(product_variant: @variant)
    assert item, "expected the scanned variant to be in the cart"
    assert_equal 1, item.quantity
  end

  test "scanning the same SKU twice increments the quantity" do
    2.times { post scan_order_items_path(org_slug: @org.slug), params: { code: "CAM-001-AZ-M" } }

    item = cart.order_items.find_by(product_variant: @variant)
    assert_equal 2, item.quantity
  end

  test "scanning tolerates surrounding whitespace from the scanner" do
    post scan_order_items_path(org_slug: @org.slug), params: { code: "  CAM-001-AZ-M " }
    assert_equal 1, cart.order_items.where(product_variant: @variant).sum(:quantity)
  end

  test "scanning tolerates keyboard-layout punctuation swaps (dash typed as apostrophe)" do
    dashed = @product.product_variants.create!(
      organisation: @org, name: "Kubrix", sku: "KBX-CB-003",
      unit_price_cents: 500, unit_price_currency: "EUR",
      published: true, available: true, is_default: false
    )

    # A PT-layout scanner turns "-" into "'": KBX-CB-003 arrives as KBX'CB'003.
    post scan_order_items_path(org_slug: @org.slug), params: { code: "KBX'CB'003" }

    item = cart.order_items.find_by(product_variant: dashed)
    assert item, "expected the dashed SKU to resolve from the apostrophe variant"
    assert_equal 1, item.quantity
  end

  test "ambiguous normalized match is treated as not found" do
    @product.product_variants.create!(organisation: @org, name: "A", sku: "AB-1",
                                      unit_price_cents: 100, unit_price_currency: "EUR",
                                      published: true, available: true, is_default: false)
    @product.product_variants.create!(organisation: @org, name: "B", sku: "AB1",
                                      unit_price_cents: 100, unit_price_currency: "EUR",
                                      published: true, available: true, is_default: false)

    # Both normalize to "AB1" — must NOT guess.
    post scan_order_items_path(org_slug: @org.slug), params: { code: "AB'1" }
    assert_not_nil flash[:alert]
    assert_nil cart&.order_items&.find_by("product_variant_id IN (?)",
               @product.product_variants.where(sku: %w[AB-1 AB1]).pluck(:id))
  end

  test "scanning a product with a per-variant minimum seeds the line at the minimum" do
    bricks = Product.create!(organisation: @org, name: "Hollow Brick", sku: "BRICK",
                             published: true, available: true,
                             min_quantity: 5, min_quantity_type: "m²", min_quantity_scope: "per_variant")
    v = bricks.product_variants.create!(organisation: @org, name: "Std", sku: "BRICK-STD",
                                        unit_price_cents: 300, unit_price_currency: "EUR",
                                        published: true, available: true, is_default: false, track_stock: false)

    # First scan must seed at the minimum (5), not 1, or the save would fail.
    post scan_order_items_path(org_slug: @org.slug), params: { code: "BRICK-STD" }
    item = cart.order_items.find_by(product_variant: v)
    assert item, "expected the min-quantity product to be added"
    assert_equal 5, item.quantity

    # Subsequent scans increment by one.
    post scan_order_items_path(org_slug: @org.slug), params: { code: "BRICK-STD" }
    assert_equal 6, item.reload.quantity
  end

  test "scanning an unknown code adds nothing and flashes an alert" do
    post scan_order_items_path(org_slug: @org.slug), params: { code: "DOES-NOT-EXIST" }
    assert_redirected_to cart_path(org_slug: @org.slug)
    assert_not_nil flash[:alert]
    assert_nil cart&.order_items&.first
  end

  test "scanning a SKU from another org is not found" do
    other_org = Organisation.create!(name: "Other Org", currency: "EUR")
    other_product = Product.create!(organisation: other_org, name: "Outro", sku: "X", published: true)
    other_product.product_variants.create!(organisation: other_org, name: "V", sku: "OTHER-SKU",
                                            unit_price_cents: 100, unit_price_currency: "EUR",
                                            published: true, available: true, is_default: false)

    post scan_order_items_path(org_slug: @org.slug), params: { code: "OTHER-SKU" }
    assert_not_nil flash[:alert]
    assert_nil cart&.order_items&.first
  end
end
