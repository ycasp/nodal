require "test_helper"

class StockRulesServiceTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(
      name: "Test Organisation",
      slug: "test-org-#{SecureRandom.hex(4)}",
      currency: "EUR",
      tax_rate: 0.23,
      out_of_stock_strategy: "hide"
    )
    @service = StockRulesService.new(@organisation)
  end

  def simple_product(published: true, available: true)
    Product.create!(
      organisation: @organisation,
      name: "Product #{SecureRandom.hex(4)}",
      slug: "product-#{SecureRandom.hex(4)}",
      unit_price: 1000,
      published: published,
      available: available
    )
  end

  test "non-tracked variant is forced available even when stuck at false" do
    product = simple_product(available: false)
    variant = product.default_variant
    variant.update_columns(track_stock: false, available: false, published: true)

    @service.apply_to_variant(variant)

    assert variant.reload.available, "non-tracked variant must become available"
    assert product.reload.available, "product must roll up to available"
  end

  test "non-tracked variant that is already available stays available" do
    product = simple_product(available: true)
    variant = product.default_variant
    variant.update_columns(track_stock: false, available: true, published: true)

    @service.apply_to_variant(variant)

    assert variant.reload.available
  end

  test "tracked track_only variant stays available with zero stock" do
    product = simple_product(available: false)
    variant = product.default_variant
    variant.update_columns(track_stock: true, stock_policy: "track_only",
                           stock_quantity: 0, available: false, published: true)

    @service.apply_to_variant(variant)

    assert variant.reload.available
    assert product.reload.available
  end

  test "tracked hide variant reflects actual stock" do
    product = simple_product(available: true)
    variant = product.default_variant
    variant.update_columns(track_stock: true, stock_policy: "hide",
                           stock_quantity: 0, available: true, published: true)

    @service.apply_to_variant(variant)

    refute variant.reload.available, "out-of-stock tracked variant must become unavailable"

    variant.update_columns(stock_quantity: 5)
    @service.apply_to_variant(variant)

    assert variant.reload.available, "in-stock tracked variant must become available"
  end
  # --- StockEvent recording -------------------------------------------------

  test "a variant dropping to zero records an out_of_stock event" do
    variant = simple_product.default_variant
    variant.update_columns(track_stock: true, stock_quantity: 5)

    variant.update!(stock_quantity: 0)

    assert_difference -> { StockEvent.count }, 1 do
      @service.apply_to_variant(variant)
    end

    event = StockEvent.last
    assert_equal StockEvent::OUT_OF_STOCK, event.kind
    assert_equal 5, event.from_quantity
    assert_equal 0, event.to_quantity
    assert_equal variant.id, event.product_variant_id
    assert_equal @organisation.id, event.organisation_id
    assert_equal "app", event.source
  end

  test "a variant coming back records a back_in_stock event" do
    variant = simple_product.default_variant
    variant.update_columns(track_stock: true, stock_quantity: 0)

    variant.update!(stock_quantity: 8)
    @service.apply_to_variant(variant)

    assert_equal StockEvent::BACK_IN_STOCK, StockEvent.last.kind
  end

  test "a sweep with no stock change records nothing" do
    variant = simple_product.default_variant
    variant.update_columns(track_stock: true, stock_quantity: 0)

    # What RecalculateStockJob does: apply the rules without any preceding save.
    assert_no_difference -> { StockEvent.count } do
      @service.apply_to_variant(variant)
    end
  end

  test "a freshly created variant records nothing" do
    product = simple_product
    variant = product.product_variants.create!(name: "New", stock_quantity: 10, track_stock: true)

    assert_no_difference -> { StockEvent.count } do
      @service.apply_to_variant(variant)
    end
  end

  test "a non-tracked variant records nothing" do
    variant = simple_product.default_variant
    variant.update_columns(track_stock: false, stock_quantity: 5)

    variant.update!(stock_quantity: 0)

    assert_no_difference -> { StockEvent.count } do
      @service.apply_to_variant(variant)
    end
  end

  test "applying the rules twice for the same save records a single event" do
    variant = simple_product.default_variant
    variant.update_columns(track_stock: true, stock_quantity: 5)

    variant.update!(stock_quantity: 0)

    assert_difference -> { StockEvent.count }, 1 do
      @service.apply_to_variant(variant)
      @service.apply_to_variant(variant)
    end
  end

  test "a drop that stays above the threshold records nothing" do
    variant = simple_product.default_variant
    variant.update_columns(track_stock: true, stock_quantity: 40)

    variant.update!(stock_quantity: 20)

    assert_no_difference -> { StockEvent.count } do
      @service.apply_to_variant(variant)
    end
  end
end
