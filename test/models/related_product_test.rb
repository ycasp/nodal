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
end
