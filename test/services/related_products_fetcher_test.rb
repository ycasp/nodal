require "test_helper"

class RelatedProductsFetcherTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(
      name: "Test Organisation",
      slug: "test-org-#{SecureRandom.hex(4)}",
      currency: "EUR",
      tax_rate: 0.23,
      show_related_products: true
    )

    @category = Category.create!(
      organisation: @organisation,
      name: "Test Category",
      slug: "test-category-#{SecureRandom.hex(4)}"
    )

    @product = Product.create!(
      organisation: @organisation,
      name: "Main Product",
      slug: "main-product-#{SecureRandom.hex(4)}",
      unit_price: 1000,
      available: true
    )

    # Assign category to product
    CategoryProduct.create!(category: @category, product: @product)

    @related1 = Product.create!(
      organisation: @organisation,
      name: "Related Product 1",
      slug: "related-product-1-#{SecureRandom.hex(4)}",
      unit_price: 1500,
      available: true
    )
    CategoryProduct.create!(category: @category, product: @related1)

    @related2 = Product.create!(
      organisation: @organisation,
      name: "Related Product 2",
      slug: "related-product-2-#{SecureRandom.hex(4)}",
      unit_price: 2000,
      available: true
    )
    CategoryProduct.create!(category: @category, product: @related2)
  end

  test "returns empty array when feature disabled at org level" do
    @organisation.update!(show_related_products: false)

    fetcher = RelatedProductsFetcher.new(product: @product)
    result = fetcher.fetch

    assert_equal [], result
  end

  test "returns empty array when feature disabled at product level" do
    @product.update!(hide_related_products: true)

    fetcher = RelatedProductsFetcher.new(product: @product)
    result = fetcher.fetch

    assert_equal [], result
  end

  test "returns manual related products in order" do
    RelatedProduct.create!(product: @product, related_product: @related2, position: 1)
    RelatedProduct.create!(product: @product, related_product: @related1, position: 2)

    fetcher = RelatedProductsFetcher.new(product: @product)
    result = fetcher.fetch

    assert_equal 2, result.size
    assert_equal @related2, result.first
    assert_equal @related1, result.second
  end

  test "auto-fills from same category when fewer than limit" do
    # Only add one manual related product
    RelatedProduct.create!(product: @product, related_product: @related1, position: 1)

    fetcher = RelatedProductsFetcher.new(product: @product, limit: 4)
    result = fetcher.fetch

    assert result.size >= 1
    assert result.include?(@related1)
  end

  test "excludes unavailable products from auto-fill" do
    @related1.update!(available: false)

    fetcher = RelatedProductsFetcher.new(product: @product, limit: 4)
    result = fetcher.fetch

    assert_not result.include?(@related1)
  end

  test "excludes the source product from results" do
    fetcher = RelatedProductsFetcher.new(product: @product, limit: 4)
    result = fetcher.fetch

    assert_not result.include?(@product)
  end

  test "respects limit parameter" do
    # Create more products
    5.times do |i|
      p = Product.create!(
        organisation: @organisation,
        name: "Extra Product #{i}",
        slug: "extra-product-#{i}-#{SecureRandom.hex(4)}",
        unit_price: 1000 + i * 100,
        available: true
      )
      CategoryProduct.create!(category: @category, product: p)
    end

    fetcher = RelatedProductsFetcher.new(product: @product, limit: 3)
    result = fetcher.fetch

    assert_equal 3, result.size
  end

  test "manual products take priority over auto-filled" do
    # Create a manual relationship
    RelatedProduct.create!(product: @product, related_product: @related1, position: 1)

    fetcher = RelatedProductsFetcher.new(product: @product, limit: 4)
    result = fetcher.fetch

    # Manual product should be first
    assert_equal @related1, result.first
  end

  test "does not duplicate products when manual and auto-fill overlap" do
    RelatedProduct.create!(product: @product, related_product: @related1, position: 1)

    fetcher = RelatedProductsFetcher.new(product: @product, limit: 4)
    result = fetcher.fetch

    # Count occurrences of related1
    count = result.count { |p| p.id == @related1.id }
    assert_equal 1, count
  end
end
