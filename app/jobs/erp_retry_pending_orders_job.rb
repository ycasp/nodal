class ErpRetryPendingOrdersJob < ApplicationJob
  queue_as :erp_sync

  discard_on ActiveRecord::RecordNotFound

  # Re-enqueues OrderPushJob for every placed order belonging to a customer
  # whose `external_id` has just been set. Fired by the Customer
  # after_update_commit hook when the column transitions nil -> present
  # (typically because ERP sync reconciled a rep-created customer).
  #
  # OrderPushService's own guards (push_synced?, push_exhausted?, ERP config)
  # take care of skipping orders that shouldn't go out — we just kick the
  # tyres on everything that was previously held back.
  def perform(customer_id)
    customer = Customer.find(customer_id)
    return if customer.external_id.blank?

    pending_orders = customer.orders.placed.where(push_status: %w[pending failed])
    return if pending_orders.empty?

    pending_orders.find_each do |order|
      OrderPushJob.perform_later(order.id)
    end

    Rails.logger.info(
      "[ErpRetryPendingOrdersJob] Enqueued #{pending_orders.count} order(s) " \
      "for retry on customer ##{customer.id} (external_id: #{customer.external_id})"
    )
  end
end
