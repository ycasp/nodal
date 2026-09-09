require "test_helper"

class RelatedProductTest < ActiveSupport::TestCase
  setup do
    @organisation = Organisation.create!(
      name: "Test Organisation",
      slug: "test-org-#{SecureRandom.hex(4)}",
      currency: "EUR",
      tax_rate: 0.23
    )

    @product1 = Product.create!(
      organisation: @organisation,
      name: "Product 1",
      slug: "product-1-#{SecureRandom.hex(4)}",
      unit_price: 1000
    )

    @product2 = Product.create!(
      organisation: @organisation,
      name: "Product 2",
      slug: "product-2-#{SecureRandom.hex(4)}",
      unit_price: 2000
    )
  end

  test "creates valid related product association" do
    related = RelatedProduct.new(
      product: @product1,
      related_product: @product2
    )

    assert related.valid?
    assert related.save
  end

  test "does not allow duplicate associations" do
    RelatedProduct.create!(
      product: @product1,
      related_product: @product2
    )

    duplicate = RelatedProduct.new(
      product: @product1,
      related_product: @product2
    )

    assert_not duplicate.valid?
    assert duplicate.errors[:product_id].any?
  end

  test "does not allow self-referential associations" do
    related = RelatedProduct.new(
      product: @product1,
      related_product: @product1
    )

    assert_not related.valid?
    assert related.errors[:base].any?
  end

  test "does not allow products from different organisations" do
    other_org = Organisation.create!(
      name: "Other Organisation",
      slug: "other-org-#{SecureRandom.hex(4)}",
      currency: "EUR"
    )

    other_product = Product.create!(
      organisation: other_org,
      name: "Other Product",
      slug: "other-product-#{SecureRandom.hex(4)}",
      unit_price: 3000
    )

    related = RelatedProduct.new(
      product: @product1,
      related_product: other_product
    )

    assert_not related.valid?
    assert related.errors[:base].any?
  end

  test "positions are managed with acts_as_list" do
    related1 = RelatedProduct.create!(
      product: @product1,
      related_product: @product2
    )

    product3 = Product.create!(
      organisation: @organisation,
      name: "Product 3",
      slug: "product-3-#{SecureRandom.hex(4)}",
      unit_price: 3000
    )

    related2 = RelatedProduct.create!(
      product: @product1,
      related_product: product3
    )

    assert_equal 1, related1.reload.position
    assert_equal 2, related2.reload.position
  end
  # Links are stored in both directions. These cover the backfill for the ones
  # created before that was true — RelatedProductsFetcher only reads
  # `product_id = self`, so a one-sided link is invisible from the other side.
  test "without_mirror finds only one-sided links" do
    one_sided = RelatedProduct.create!(product: @product1, related_product: @product2)

    assert_includes RelatedProduct.without_mirror, one_sided

    RelatedProduct.create!(product: @product2, related_product: @product1)

    assert_not_includes RelatedProduct.without_mirror, one_sided
  end

  test "create_missing_mirrors! adds the missing direction" do
    RelatedProduct.create!(product: @product1, related_product: @product2)

    result = RelatedProduct.create_missing_mirrors!(dry_run: false)

    assert_equal 1, result[:created].size
    assert RelatedProduct.exists?(product: @product2, related_product: @product1)
  end

  test "a dry run reports without writing" do
    RelatedProduct.create!(product: @product1, related_product: @product2)

    result = RelatedProduct.create_missing_mirrors!(dry_run: true)

    assert_equal 1, result[:created].size
    assert_not RelatedProduct.exists?(product: @product2, related_product: @product1)
  end

  test "running it twice changes nothing the second time" do
    RelatedProduct.create!(product: @product1, related_product: @product2)

    RelatedProduct.create_missing_mirrors!(dry_run: false)
    second = RelatedProduct.create_missing_mirrors!(dry_run: false)

    assert_empty second[:created]
    assert_equal 2, RelatedProduct.count
  end

  test "leaves already-mirrored pairs alone" do
    RelatedProduct.create!(product: @product1, related_product: @product2)
    RelatedProduct.create!(product: @product2, related_product: @product1)

    result = RelatedProduct.create_missing_mirrors!(dry_run: false)

    assert_empty result[:created]
    assert_equal 2, RelatedProduct.count
  end

  # One unmirrorable leftover must not stop the rest, which is the whole point
  # of reporting instead of raising.
  test "reports a pair it cannot mirror and carries on with the others" do
    other_org = Organisation.create!(name: "Other Org", slug: "other-#{SecureRandom.hex(4)}", currency: "EUR", tax_rate: 0.23)
    stranger = Product.create!(organisation: other_org, name: "Stranger", slug: "stranger-#{SecureRandom.hex(4)}", unit_price: 1000)

    good = RelatedProduct.create!(product: @product1, related_product: @product2)
    bad = RelatedProduct.new(product: @product1, related_product: stranger)
    bad.save!(validate: false)

    result = RelatedProduct.create_missing_mirrors!(dry_run: false)

    assert_equal 1, result[:created].size
    assert_equal 1, result[:skipped].size
    assert RelatedProduct.exists?(product: @product2, related_product: @product1)
    assert_not_nil good.reload
  end

  test "the scope narrows the work to one organisation" do
    other_org = Organisation.create!(name: "Other Org", slug: "other-#{SecureRandom.hex(4)}", currency: "EUR", tax_rate: 0.23)
    a = Product.create!(organisation: other_org, name: "A", slug: "a-#{SecureRandom.hex(4)}", unit_price: 1000)
    b = Product.create!(organisation: other_org, name: "B", slug: "b-#{SecureRandom.hex(4)}", unit_price: 1000)

    RelatedProduct.create!(product: @product1, related_product: @product2)
    RelatedProduct.create!(product: a, related_product: b)

    scope = RelatedProduct.joins(:product).where(products: { organisation_id: other_org.id })
    result = RelatedProduct.create_missing_mirrors!(scope: scope, dry_run: false)

    assert_equal 1, result[:created].size
    assert RelatedProduct.exists?(product: b, related_product: a)
    assert_not RelatedProduct.exists?(product: @product2, related_product: @product1)
  end
end
