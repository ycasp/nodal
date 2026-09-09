require "test_helper"

class ProductVariantTest < ActiveSupport::TestCase
  def setup
    @org = Organisation.create!(name: "Stock Org", low_stock_threshold: 5)
    @product = Product.create!(organisation: @org, name: "Widget", unit_price: 1000, published: true)
    @variant = @product.default_variant
  end

  test "stock_control_status classifies against the threshold" do
    @variant.update!(track_stock: false)
    assert_equal :untracked, @variant.stock_control_status(5)

    @variant.update!(track_stock: true, stock_quantity: 0)
    assert_equal :out_of_stock, @variant.stock_control_status(5)

    @variant.update!(stock_quantity: 5)
    assert_equal :at_risk, @variant.stock_control_status(5)

    @variant.update!(stock_quantity: 6)
    assert_equal :ok, @variant.stock_control_status(5)
  end

  test "stock scopes filter tracked variants by threshold" do
    @variant.update!(track_stock: true, stock_quantity: 0)
    assert_includes ProductVariant.stock_out, @variant
    assert_not_includes ProductVariant.stock_at_risk(5), @variant

    @variant.update!(stock_quantity: 3)
    assert_includes ProductVariant.stock_at_risk(5), @variant
    assert_includes ProductVariant.stock_low_or_out(5), @variant
    assert_not_includes ProductVariant.stock_out, @variant
  end

  test "real_units excludes the placeholder base variant of variable products" do
    variable = Product.create!(organisation: @org, name: "Var", unit_price: 1000, published: true, has_variants: true)
    base = variable.default_variant

    assert_not_includes ProductVariant.real_units, base, "placeholder base variant should be excluded"
    assert_includes ProductVariant.real_units, @variant, "a simple product's default variant is a real unit"
  end
end
