class OrderPushRetryJob < ApplicationJob
  queue_as :erp_sync

  # Safety-net: iterates every org with order push enabled and enqueues
  # OrderPushJob for any order stuck in `pending` or `failed`. The `pushable`
  # scope already caps attempts and enforces a per-order cooldown so orders
  # that keep failing don't get hammered.
  def perform
    ErpConfiguration.where(enabled: true, sync_orders: true).find_each do |config|
      next unless config.can_sync_orders?

      config.organisation.orders.pushable.pluck(:id).each do |order_id|
        OrderPushJob.perform_later(order_id)
      end
    end
  end
end
