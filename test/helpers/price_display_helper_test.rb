require "test_helper"

class PriceDisplayHelperTest < ActionView::TestCase
  def setup
    @org = Organisation.create!(name: "Price Org")
    @category = Category.create!(organisation: @org, name: "Comunhão", slug: "com-#{SecureRandom.hex(4)}")
    @included = Product.create!(organisation: @org, name: "Incluído", unit_price: 1000, published: true)
    @other = Product.create!(organisation: @org, name: "Outro", unit_price: 1000, published: true)
    CategoryProduct.create!(category: @category, product: @included)
    CategoryProduct.create!(category: @category, product: @other)
    @customer = Customer.create!(organisation: @org, company_name: "Acme", contact_name: "J", active: true)
    @cu = CustomerUser.create!(organisation: @org, customer: @customer, email: "j@acme.test",
      password: "password123", password_confirmation: "password123", contact_name: "J", active: true)
    @order = Order.create!(organisation: @org, customer: @customer, customer_user: @cu)
  end

  def cart_context
    CartDiscountContext.new(@order.order_items.includes(:product_variant, product: :categories).to_a)
  end

  test "variant_cart_toward counts the whole category for a category discount" do
    # 4 units of another product in the same category, none of @included yet.
    @order.order_items.create!(product: @other, product_variant: @other.default_variant, quantity: 4)
    src = ProductDiscount.create!(organisation: @org, category: @category, discount_type: "percentage",
      discount_value: 0.12, condition_type: "quantity", condition_scope: "summed", min_quantity: 6)

    toward = variant_cart_toward(cart_context, @included, nil, { type: :quantity }, true, src)
    assert_equal 4, toward, "the grid counter must include other category products already in the cart"
  end

  test "variant_cart_toward ignores units of variants excluded from the discount" do
    @order.order_items.create!(product: @other, product_variant: @other.default_variant, quantity: 4)
    @other.default_variant.update!(exclude_from_discounts: true)
    src = ProductDiscount.create!(organisation: @org, category: @category, discount_type: "percentage",
      discount_value: 0.12, condition_type: "quantity", condition_scope: "summed", min_quantity: 6)

    toward = variant_cart_toward(cart_context, @included, nil, { type: :quantity }, true, src)
    assert_equal 0, toward, "excluded units must not count toward the category threshold"
  end

  test "variant_cart_toward falls back to the product total for a product discount" do
    @order.order_items.create!(product: @other, product_variant: @other.default_variant, quantity: 4)
    @order.order_items.create!(product: @included, product_variant: @included.default_variant, quantity: 2)
    src = ProductDiscount.create!(organisation: @org, product: @included, discount_type: "percentage",
      discount_value: 0.12, condition_type: "quantity", condition_scope: "summed", min_quantity: 6)

    toward = variant_cart_toward(cart_context, @included, nil, { type: :quantity }, true, src)
    assert_equal 2, toward, "a product discount counts only its own product, not the category"
  end
end
