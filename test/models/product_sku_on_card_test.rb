require "test_helper"

# show_sku_on_card? combines the org opt-in with the per-product suppression,
# mirroring the show_related_products? pattern.
class ProductSkuOnCardTest < ActiveSupport::TestCase
  setup do
    @org = Organisation.create!(name: "SKU Org", currency: "EUR")
  end

  def product(hidden:)
    @seq = (@seq || 0) + 1
    Product.create!(organisation: @org, name: "P#{@seq}", sku: "ABC#{@seq}", hide_sku_on_card: hidden)
  end

  test "shown when org opts in and the product does not suppress it" do
    @org.update!(show_product_sku_on_card: true)
    assert product(hidden: false).show_sku_on_card?
  end

  test "hidden per product even when the org opts in" do
    @org.update!(show_product_sku_on_card: true)
    assert_not product(hidden: true).show_sku_on_card?
  end

  test "hidden when the org has not opted in, regardless of the product flag" do
    @org.update!(show_product_sku_on_card: false)
    assert_not product(hidden: false).show_sku_on_card?
    assert_not product(hidden: true).show_sku_on_card?
  end

  test "defaults: org off, product not hidden" do
    assert_not @org.show_product_sku_on_card?
    assert_not product(hidden: false).hide_sku_on_card?
  end
end
