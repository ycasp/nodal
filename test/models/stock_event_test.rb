require "test_helper"

class StockEventTest < ActiveSupport::TestCase
  test "going from stock to zero is an out_of_stock event" do
    assert_equal StockEvent::OUT_OF_STOCK,
                 StockEvent.kind_for(from: 5, to: 0, low_stock_threshold: 5)
  end

  test "a negative landing still counts as out_of_stock" do
    assert_equal StockEvent::OUT_OF_STOCK,
                 StockEvent.kind_for(from: 2, to: -3, low_stock_threshold: 5)
  end

  test "coming back from zero is a back_in_stock event" do
    assert_equal StockEvent::BACK_IN_STOCK,
                 StockEvent.kind_for(from: 0, to: 4, low_stock_threshold: 5)
  end

  test "crossing down into the threshold is a low_stock event" do
    assert_equal StockEvent::LOW_STOCK,
                 StockEvent.kind_for(from: 20, to: 3, low_stock_threshold: 5)
  end

  test "moving within the threshold is not a new low_stock event" do
    assert_nil StockEvent.kind_for(from: 4, to: 3, low_stock_threshold: 5)
  end

  test "a drop that never reaches the threshold is not an event" do
    assert_nil StockEvent.kind_for(from: 40, to: 20, low_stock_threshold: 5)
  end

  test "zero to zero is not an event" do
    assert_nil StockEvent.kind_for(from: 0, to: 0, low_stock_threshold: 5)
  end

  test "a threshold of zero disables low_stock detection" do
    assert_nil StockEvent.kind_for(from: 20, to: 3, low_stock_threshold: 0)
  end

  test "nil quantities are treated as zero" do
    assert_equal StockEvent::BACK_IN_STOCK,
                 StockEvent.kind_for(from: nil, to: 7, low_stock_threshold: 5)
  end

  test "kind must be one of the known kinds" do
    event = StockEvent.new(kind: "exploded", occurred_at: Time.current)
    event.valid?
    assert_includes event.errors[:kind], "is not included in the list"
  end
end
