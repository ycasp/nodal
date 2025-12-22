require "test_helper"

class OrderDiscountTest < ActiveSupport::TestCase
  def setup
    @organisation = Organisation.create!(name: "Test Org")
    @discount = OrderDiscount.new(
      organisation: @organisation,
      discount_type: "percentage",
      discount_value: 0.10,
      min_order_amount_cents: 10000,
      active: true
    )
  end

  test "valid order discount" do
    assert @discount.valid?
  end

  test "requires organisation" do
    @discount.organisation = nil
    assert_not @discount.valid?
    assert_includes @discount.errors[:organisation], "must exist"
  end

  test "requires discount_type" do
    @discount.discount_type = nil
    assert_not @discount.valid?
    assert_includes @discount.errors[:discount_type], "can't be blank"
  end

  test "discount_type must be percentage or fixed" do
    @discount.discount_type = "invalid"
    assert_not @discount.valid?
    assert_includes @discount.errors[:discount_type], "is not included in the list"
  end

  test "requires discount_value" do
    @discount.discount_value = nil
    assert_not @discount.valid?
    assert_includes @discount.errors[:discount_value], "can't be blank"
  end

  test "discount_value must be greater than 0" do
    @discount.discount_value = 0
    assert_not @discount.valid?
    assert_includes @discount.errors[:discount_value], "must be greater than 0"
  end

  test "percentage discount_value must be <= 1" do
    @discount.discount_type = "percentage"
    @discount.discount_value = 1.5
    assert_not @discount.valid?
    assert_includes @discount.errors[:discount_value], "must be between 0 and 1 for percentage discounts (e.g., 0.15 for 15%)"
  end

  test "fixed discount_value can be greater than 1" do
    @discount.discount_type = "fixed"
    @discount.discount_value = 50.00
    assert @discount.valid?
  end

  test "requires min_order_amount_cents" do
    @discount.min_order_amount_cents = nil
    assert_not @discount.valid?
    assert_includes @discount.errors[:min_order_amount_cents], "can't be blank"
  end

  test "min_order_amount_cents must be greater than 0" do
    @discount.min_order_amount_cents = 0
    assert_not @discount.valid?
    assert_includes @discount.errors[:min_order_amount_cents], "must be greater than 0"
  end

  test "valid_until must be after valid_from" do
    @discount.valid_from = Date.today
    @discount.valid_until = Date.yesterday
    assert_not @discount.valid?
    assert_includes @discount.errors[:valid_until], "must be after valid from date"
  end

  test "percentage? returns true for percentage type" do
    @discount.discount_type = "percentage"
    assert @discount.percentage?
    assert_not @discount.fixed?
  end

  test "fixed? returns true for fixed type" do
    @discount.discount_type = "fixed"
    assert @discount.fixed?
    assert_not @discount.percentage?
  end

  test "perpetual? returns true when no dates set" do
    @discount.valid_from = nil
    @discount.valid_until = nil
    assert @discount.perpetual?
  end

  test "perpetual? returns false when dates are set" do
    @discount.valid_from = Date.today
    assert_not @discount.perpetual?
  end

  test "value_display returns percentage format" do
    @discount.discount_type = "percentage"
    @discount.discount_value = 0.15
    assert_equal "15%", @discount.value_display
  end

  test "value_display returns fixed value" do
    @discount.discount_type = "fixed"
    @discount.discount_value = 25.00
    assert_equal 25.00, @discount.value_display
  end

  test "min_amount_display returns formatted money" do
    @discount.min_order_amount_cents = 10000
    assert_match(/100/, @discount.min_amount_display)
  end

  test "valid_period_display for perpetual" do
    @discount.valid_from = nil
    @discount.valid_until = nil
    assert_equal "No expiry", @discount.valid_period_display
  end

  test "valid_period_display with both dates" do
    @discount.valid_from = Date.new(2025, 1, 1)
    @discount.valid_until = Date.new(2025, 12, 31)
    assert_equal "2025-01-01 to 2025-12-31", @discount.valid_period_display
  end

  test "calculate_discount for percentage" do
    @discount.discount_type = "percentage"
    @discount.discount_value = 0.10
    @discount.min_order_amount_cents = 5000

    order_total = Money.new(10000, "EUR")
    discount_amount = @discount.calculate_discount(order_total)

    assert_equal Money.new(1000, "EUR"), discount_amount
  end

  test "calculate_discount for fixed" do
    @discount.discount_type = "fixed"
    @discount.discount_value = 15.00
    @discount.min_order_amount_cents = 5000

    order_total = Money.new(10000, "EUR")
    discount_amount = @discount.calculate_discount(order_total)

    assert_equal Money.new(1500, "EUR"), discount_amount
  end

  test "calculate_discount returns zero if order below minimum" do
    @discount.min_order_amount_cents = 20000

    order_total = Money.new(10000, "EUR")
    discount_amount = @discount.calculate_discount(order_total)

    assert_equal Money.new(0, "EUR"), discount_amount
  end

  test "applicable_to? returns true when order meets minimum" do
    @discount.min_order_amount_cents = 5000
    order_total = Money.new(10000, "EUR")

    assert @discount.applicable_to?(order_total)
  end

  test "applicable_to? returns false when order below minimum" do
    @discount.min_order_amount_cents = 20000
    order_total = Money.new(10000, "EUR")

    assert_not @discount.applicable_to?(order_total)
  end

  test "active scope filters by active flag and dates" do
    @organisation.order_discounts.destroy_all

    active_discount = OrderDiscount.create!(
      organisation: @organisation,
      discount_type: "percentage",
      discount_value: 0.10,
      min_order_amount_cents: 5000,
      active: true
    )

    inactive_discount = OrderDiscount.create!(
      organisation: @organisation,
      discount_type: "percentage",
      discount_value: 0.15,
      min_order_amount_cents: 10000,
      active: false
    )

    expired_discount = OrderDiscount.create!(
      organisation: @organisation,
      discount_type: "percentage",
      discount_value: 0.20,
      min_order_amount_cents: 15000,
      active: true,
      valid_until: Date.yesterday
    )

    future_discount = OrderDiscount.create!(
      organisation: @organisation,
      discount_type: "percentage",
      discount_value: 0.25,
      min_order_amount_cents: 20000,
      active: true,
      valid_from: Date.tomorrow
    )

    active_discounts = @organisation.order_discounts.active

    assert_includes active_discounts, active_discount
    assert_not_includes active_discounts, inactive_discount
    assert_not_includes active_discounts, expired_discount
    assert_not_includes active_discounts, future_discount
  end

  test "by_min_amount scope orders by min_order_amount ascending" do
    @organisation.order_discounts.destroy_all

    high = OrderDiscount.create!(
      organisation: @organisation,
      discount_type: "percentage",
      discount_value: 0.20,
      min_order_amount_cents: 20000,
      active: true
    )

    low = OrderDiscount.create!(
      organisation: @organisation,
      discount_type: "percentage",
      discount_value: 0.05,
      min_order_amount_cents: 5000,
      active: true
    )

    medium = OrderDiscount.create!(
      organisation: @organisation,
      discount_type: "percentage",
      discount_value: 0.10,
      min_order_amount_cents: 10000,
      active: true
    )

    sorted = @organisation.order_discounts.by_min_amount

    assert_equal [low, medium, high], sorted.to_a
  end
end
