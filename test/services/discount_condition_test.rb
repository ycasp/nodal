require "test_helper"

# Covers the quantity/amount condition engine shared by ProductDiscount and
# CustomerProductDiscount (HasDiscountCondition + DiscountCalculator).
class DiscountConditionTest < ActiveSupport::TestCase
  def setup
    @org = Organisation.create!(name: "Cond Test Org")
    @customer = Customer.create!(organisation: @org, company_name: "Acme", contact_name: "J", active: true)
    @cu = CustomerUser.create!(organisation: @org, customer: @customer, email: "j@acme.test",
      password: "password123", password_confirmation: "password123", contact_name: "J", active: true)
    @product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000, published: true) # €10
  end

  def final_price(quantity)
    DiscountCalculator.new(product: @product, customer: @customer, quantity: quantity).final_price
  end

  test "product discount with amount condition applies only when the line value meets it" do
    ProductDiscount.create!(organisation: @org, product: @product, discount_type: "percentage",
      discount_value: 0.10, condition_type: "amount", min_amount_cents: 5000) # spend €50 on this line

    assert_equal Money.new(1000, "EUR"), final_price(4) # €40 line < €50 -> no discount
    assert_equal Money.new(900, "EUR"), final_price(5)  # €50 line -> 10% off
  end

  test "product discount with quantity condition still works" do
    ProductDiscount.create!(organisation: @org, product: @product, discount_type: "percentage",
      discount_value: 0.10, condition_type: "quantity", min_quantity: 5)

    assert_equal Money.new(1000, "EUR"), final_price(4)
    assert_equal Money.new(900, "EUR"), final_price(5)
  end

  test "customer special price with no condition always applies" do
    CustomerProductDiscount.create!(organisation: @org, customer: @customer, product: @product,
      discount_type: "percentage", discount_value: 0.20) # condition_type defaults to none

    assert_equal Money.new(800, "EUR"), final_price(1)
  end

  test "customer special price with quantity condition gates on quantity" do
    CustomerProductDiscount.create!(organisation: @org, customer: @customer, product: @product,
      discount_type: "percentage", discount_value: 0.20, condition_type: "quantity", min_quantity: 10)

    assert_equal Money.new(1000, "EUR"), final_price(9)
    assert_equal Money.new(800, "EUR"), final_price(10)
  end

  test "customer special price with amount condition gates on line value" do
    CustomerProductDiscount.create!(organisation: @org, customer: @customer, product: @product,
      discount_type: "fixed", discount_value: 3, condition_type: "amount", min_amount_cents: 10000) # €100 line

    assert_equal Money.new(1000, "EUR"), final_price(9)  # €90 < €100 -> no discount
    assert_equal Money.new(700, "EUR"), final_price(10)  # €100 -> €3 off each unit
  end

  test "amount condition validates a positive minimum" do
    d = ProductDiscount.new(organisation: @org, product: @product, discount_type: "percentage",
      discount_value: 0.10, condition_type: "amount", min_amount_cents: 0)
    assert_not d.valid?
  end

  test "amount-condition product discount ignores the product's min order quantity rule" do
    @product.update!(min_quantity: 50) # high min order qty
    d = ProductDiscount.new(organisation: @org, product: @product, discount_type: "percentage",
      discount_value: 0.10, condition_type: "amount", min_amount_cents: 5000)
    assert d.valid?, d.errors.full_messages.to_sentence # min_quantity rule must not block amount conditions
  end

  test "summed quantity condition is met across a product's variant lines" do
    product = Product.create!(organisation: @org, name: "Rings", published: true, has_variants: true)
    red = product.product_variants.create!(name: "R", sku: "RR", unit_price_cents: 1000,
      published: true, is_default: false, track_stock: false)
    blue = product.product_variants.create!(name: "B", sku: "RB", unit_price_cents: 1000,
      published: true, is_default: false, track_stock: false)
    ProductDiscount.create!(organisation: @org, product: product, discount_type: "percentage",
      discount_value: 0.10, condition_type: "quantity", condition_scope: "summed", min_quantity: 10)

    order = Order.create!(organisation: @org, customer: @customer, customer_user: @cu)
    order.order_items.create!(product: product, product_variant: red, quantity: 6)
    order.order_items.create!(product: product, product_variant: blue, quantity: 5)
    ctx = CartDiscountContext.new(order.order_items.to_a)

    # Per-line: a single 6-unit line is below 10 -> the discount doesn't apply.
    no_ctx = DiscountCalculator.new(product: product, customer: @customer, quantity: 6, variant: red)
    assert_nil no_ctx.all_discounts.find { |d| d[:type] == :product }

    # Summed: 6 + 5 = 11 >= 10 across the product -> the discount applies.
    with_ctx = DiscountCalculator.new(product: product, customer: @customer, quantity: 6, variant: red, cart_context: ctx)
    d = with_ctx.all_discounts.find { |x| x[:type] == :product }
    assert d && d[:meets_condition]
  end

  test "summed amount condition is met across a category total" do
    category = Category.create!(organisation: @org, name: "Cat", slug: "cat-#{SecureRandom.hex(4)}")
    p1 = Product.create!(organisation: @org, name: "P1", unit_price: 5000, published: true) # €50
    p2 = Product.create!(organisation: @org, name: "P2", unit_price: 5000, published: true) # €50
    CategoryProduct.create!(category: category, product: p1)
    CategoryProduct.create!(category: category, product: p2)
    ProductDiscount.create!(organisation: @org, category: category, discount_type: "percentage",
      discount_value: 0.10, condition_type: "amount", condition_scope: "summed", min_amount_cents: 10000) # €100

    order = Order.create!(organisation: @org, customer: @customer, customer_user: @cu)
    order.order_items.create!(product: p1, quantity: 1) # €50
    order.order_items.create!(product: p2, quantity: 1) # €50
    ctx = CartDiscountContext.new(order.order_items.includes(product: :categories).to_a)

    # €50 alone < €100 -> per-line not met
    no_ctx = DiscountCalculator.new(product: p1, customer: @customer, quantity: 1, variant: p1.default_variant)
    assert_nil no_ctx.all_discounts.find { |d| d[:type] == :category }

    # €50 + €50 = €100 across the category -> met
    with_ctx = DiscountCalculator.new(product: p1, customer: @customer, quantity: 1, variant: p1.default_variant, cart_context: ctx)
    d = with_ctx.all_discounts.find { |x| x[:type] == :category }
    assert d && d[:meets_condition]
  end

  test "summed category condition ignores units of variants excluded from the discount" do
    category = Category.create!(organisation: @org, name: "Comunhão", slug: "com-#{SecureRandom.hex(4)}")
    included = Product.create!(organisation: @org, name: "Incluído", unit_price: 1000, published: true) # €10
    excluded = Product.create!(organisation: @org, name: "Excluído", unit_price: 1000, published: true) # €10
    CategoryProduct.create!(category: category, product: included)
    CategoryProduct.create!(category: category, product: excluded)
    # Pull the excluded product out of the discount via the variant flag (the
    # "Excluir" checkbox on the category-discount form).
    excluded.default_variant.update!(exclude_from_discounts: true)

    # Buy 6 units in the category -> 12% off.
    ProductDiscount.create!(organisation: @org, category: category, discount_type: "percentage",
      discount_value: 0.12, condition_type: "quantity", condition_scope: "summed", min_quantity: 6)

    order = Order.create!(organisation: @org, customer: @customer, customer_user: @cu)
    order.order_items.create!(product: included, product_variant: included.default_variant, quantity: 2)
    order.order_items.create!(product: excluded, product_variant: excluded.default_variant, quantity: 10)
    ctx = CartDiscountContext.new(order.order_items.includes(:product_variant, product: :categories).to_a)

    # 2 eligible units + 10 excluded units: the excluded ones must NOT count, so
    # the 6-unit threshold is not reached and the discount stays locked.
    calc = DiscountCalculator.new(product: included, customer: @customer, quantity: 2,
      variant: included.default_variant, cart_context: ctx)
    d = calc.all_discounts.find { |x| x[:type] == :category }
    assert(d.nil? || !d[:meets_condition], "excluded units must not unlock the category discount")

    # Bump the eligible line to 6 -> threshold met on eligible units alone.
    order.order_items.find_by(product: included).update!(quantity: 6)
    ctx2 = CartDiscountContext.new(order.order_items.includes(:product_variant, product: :categories).to_a)
    calc2 = DiscountCalculator.new(product: included, customer: @customer, quantity: 6,
      variant: included.default_variant, cart_context: ctx2)
    d2 = calc2.all_discounts.find { |x| x[:type] == :category }
    assert d2 && d2[:meets_condition], "6 eligible units should unlock the category discount"
  end

  test "condition_display summarises the requirement" do
    qty = ProductDiscount.new(condition_type: "quantity", min_quantity: 5)
    amt = ProductDiscount.new(organisation: @org, condition_type: "amount", min_amount_cents: 5000)
    none = CustomerProductDiscount.new(condition_type: "none")
    assert_equal "5", qty.condition_display
    assert_equal "€50.00", amt.condition_display
    assert_equal "—", none.condition_display
  end
end
