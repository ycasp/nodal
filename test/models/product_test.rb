require "test_helper"

class ProductTest < ActiveSupport::TestCase
  def setup
    @org = Organisation.create!(name: "Grid Test Org")
    @product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000, published: true)
  end

  test "defaults add_to_cart_mode to default" do
    assert_equal "default", @product.add_to_cart_mode
  end

  test "on_promotion includes products with a direct product discount, excludes plain ones" do
    promo = Product.create!(organisation: @org, name: "Promo", unit_price: 1000, published: true)
    plain = Product.create!(organisation: @org, name: "Plain", unit_price: 1000, published: true)
    ProductDiscount.create!(organisation: @org, product: promo, discount_type: "percentage",
      discount_value: 0.1, condition_type: "quantity", min_quantity: 1, active: true)

    ids = @org.products.on_promotion.pluck(:id)
    assert_includes ids, promo.id
    assert_not_includes ids, plain.id
  end

  test "on_promotion covers a discounted category AND its subcategories" do
    parent = Category.create!(organisation: @org, name: "Comunhão", slug: "com-#{SecureRandom.hex(4)}")
    child = Category.create!(organisation: @org, name: "Sub", slug: "sub-#{SecureRandom.hex(4)}", parent: parent)
    in_parent = Product.create!(organisation: @org, name: "InParent", unit_price: 1000, published: true)
    in_child = Product.create!(organisation: @org, name: "InChild", unit_price: 1000, published: true)
    outside = Product.create!(organisation: @org, name: "Outside", unit_price: 1000, published: true)
    CategoryProduct.create!(category: parent, product: in_parent)
    CategoryProduct.create!(category: child, product: in_child)
    ProductDiscount.create!(organisation: @org, category: parent, discount_type: "percentage",
      discount_value: 0.12, condition_type: "quantity", condition_scope: "summed", min_quantity: 6, active: true)

    ids = @org.products.on_promotion.pluck(:id)
    assert_includes ids, in_parent.id
    assert_includes ids, in_child.id, "a discount on the parent category must cover subcategory products"
    assert_not_includes ids, outside.id
  end

  test "on_promotion excludes products whose only discount is inactive" do
    promo = Product.create!(organisation: @org, name: "Inactive", unit_price: 1000, published: true)
    ProductDiscount.create!(organisation: @org, product: promo, discount_type: "percentage",
      discount_value: 0.1, condition_type: "quantity", min_quantity: 1, active: false)
    assert_not_includes @org.products.on_promotion.pluck(:id), promo.id
  end

  test "on_promotion drops products excluded from the campaign discount" do
    category = Category.create!(organisation: @org, name: "Comunhão", slug: "com-#{SecureRandom.hex(4)}")
    included = Product.create!(organisation: @org, name: "Incluído", unit_price: 1000, published: true)
    excluded = Product.create!(organisation: @org, name: "Excluído", unit_price: 1000, published: true)
    CategoryProduct.create!(category: category, product: included)
    CategoryProduct.create!(category: category, product: excluded)
    # The excluded product's sellable (default) variant is pulled from discounts.
    excluded.default_variant.update!(exclude_from_discounts: true)
    ProductDiscount.create!(organisation: @org, category: category, discount_type: "percentage",
      discount_value: 0.12, condition_type: "quantity", condition_scope: "summed", min_quantity: 6, active: true)

    ids = @org.products.on_promotion.pluck(:id)
    assert_includes ids, included.id
    assert_not_includes ids, excluded.id, "a product excluded from the discount must not show under Campanhas"
  end

  test "rejects an invalid add_to_cart_mode" do
    @product.add_to_cart_mode = "weird"
    assert_not @product.valid?
    assert_includes @product.errors[:add_to_cart_mode], "is not included in the list"
  end

  test "grid_add_to_cart? is false for simple products even in grid mode" do
    @product.update!(add_to_cart_mode: "grid")
    assert_not @product.grid_add_to_cart?
  end

  test "grid_add_to_cart? is true when mode is grid and product has variants" do
    @product.update!(has_variants: true, add_to_cart_mode: "grid")
    assert @product.grid_add_to_cart?
  end

  test "grid_add_to_cart? is false in default mode" do
    @product.update!(has_variants: true, add_to_cart_mode: "default")
    assert_not @product.grid_add_to_cart?
  end

  test "converting variable -> simple promotes the default variant price/sku to the product" do
    product = Product.create!(organisation: @org, name: "Convertible", unit_price: nil,
                              published: true, has_variants: true)
    # Variable product: price lives on the variant, product.unit_price stays nil
    product.default_variant.update_columns(unit_price_cents: 1800, sku: "CONV-1")
    assert_nil product.reload.unit_price

    product.update!(has_variants: false)

    assert_equal 1800, product.reload.unit_price, "product price must be promoted from the variant"
    assert_equal "CONV-1", product.sku
  end

  test "converting variable -> simple does not wipe an existing variant price" do
    product = Product.create!(organisation: @org, name: "Convertible2", unit_price: nil,
                              published: true, has_variants: true)
    product.default_variant.update_columns(unit_price_cents: 2500, sku: "CONV-2")

    product.update!(has_variants: false)

    assert_equal 2500, product.reload.default_variant.unit_price_cents
    assert_equal 2500, product.unit_price
  end

  test "min_quantity_scope defaults to per_variant and rejects unknown values" do
    assert_equal "per_variant", @product.min_quantity_scope
    @product.min_quantity_scope = "weird"
    assert_not @product.valid?
  end

  test "min_quantity_combined? is only true for combined-scope variable products" do
    @product.update!(min_quantity: 12, min_quantity_scope: "combined")
    assert_not @product.min_quantity_combined?, "simple product is never combined"

    @product.update!(has_variants: true)
    assert @product.min_quantity_combined?
  end

  test "quantity_input_min is 1 for combined products and the minimum otherwise" do
    @product.update!(min_quantity: 12)
    assert_equal 12, @product.quantity_input_min

    @product.update!(has_variants: true, min_quantity_scope: "combined")
    assert_equal 1, @product.quantity_input_min
  end

  test "discounted_price_range applies a fixed discount per variant, not by extrapolating a percentage" do
    customer = Customer.create!(organisation: @org, company_name: "Acme", contact_name: "J", active: true)
    product = Product.create!(organisation: @org, name: "Rings", published: true, has_variants: true)
    product.product_variants.create!(name: "S", sku: "R-S", unit_price_cents: 1200, published: true, is_default: false, track_stock: false)
    product.product_variants.create!(name: "L", sku: "R-L", unit_price_cents: 4300, published: true, is_default: false, track_stock: false)
    CustomerProductDiscount.create!(organisation: @org, customer: customer, product: product,
      discount_type: "fixed", discount_value: 10)

    dr = product.discounted_price_range(customer)

    assert_equal Money.new(1200, "EUR"), dr[:original_min]
    assert_equal Money.new(4300, "EUR"), dr[:original_max]
    # €10 off each end: €2.00 and €33.00 — NOT €7.17 (which a single-% extrapolation gives)
    assert_equal Money.new(200, "EUR"), dr[:final_min]
    assert_equal Money.new(3300, "EUR"), dr[:final_max]
  end
end
