require "test_helper"

class CustomerProductDiscountTest < ActiveSupport::TestCase
  def setup
    @org = Organisation.create!(name: "CPD Test Org")
    @customer = Customer.create!(organisation: @org, company_name: "Acme", contact_name: "Jane", active: true)
    @product = Product.create!(organisation: @org, name: "Widget", unit_price: 10000, published: true) # €100
  end

  def build_discount(attrs = {})
    CustomerProductDiscount.new({
      organisation: @org, customer: @customer, product: @product,
      discount_type: "percentage", discount_value: 0.15
    }.merge(attrs))
  end

  test "accepts a fixed discount above the old 9.99 cap" do
    discount = build_discount(discount_type: "fixed", discount_value: 50)
    assert discount.valid?, discount.errors.full_messages.to_sentence
  end

  test "accepts a percentage discount" do
    assert build_discount(discount_type: "percentage", discount_value: 0.15).valid?
  end

  test "rejects a percentage discount above 1" do
    discount = build_discount(discount_type: "percentage", discount_value: 1.5)
    assert_not discount.valid?
    assert discount.errors[:discount_value].any?
  end

  test "rejects a non-positive value" do
    assert_not build_discount(discount_value: 0).valid?
  end

  test "calculator applies a fixed customer-product discount of €50 on a €100 product" do
    CustomerProductDiscount.create!(organisation: @org, customer: @customer, product: @product,
      discount_type: "fixed", discount_value: 50)

    calc = DiscountCalculator.new(product: @product, customer: @customer, quantity: 1)

    assert_equal Money.new(10000, "EUR"), calc.base_price
    assert_equal Money.new(5000, "EUR"), calc.final_price
  end
end
