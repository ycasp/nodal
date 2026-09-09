class OrderPushJob < ApplicationJob
  queue_as :erp_sync

  # Transient connection issues retry automatically. Permanent failures (bad
  # credentials, missing config, duplicate key conflicts) are captured by
  # OrderPushService and recorded on the order — we don't retry those.
  retry_on Erp::ConnectionError, wait: :polynomially_longer, attempts: 3

  discard_on ActiveRecord::RecordNotFound

  def perform(order_id)
    order = Order.find(order_id)
    Erp::OrderPushService.new(order: order).call
  end
end
