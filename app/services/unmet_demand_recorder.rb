# Bridges the cart stock policies to the UnmetDemand ledger.
#
# `record` is called from Order#refresh_cart! at the exact moment a line is
# removed or its quantity is capped — the only point where the *original*
# requested quantity is still in memory. It (a) upserts the current-state
# aggregate row, keyed by the login that hit the shortfall, and (b) appends an
# immutable occurrence to the history log. `resolve_for_placed_order` is called
# from Order#place! to close demands the customer ended up satisfying.
#
# Both swallow errors: demand tracking must never break a customer's cart or
# their checkout.
class UnmetDemandRecorder
  def self.record(order:, product:, product_variant:, requested:, kept:, reason:)
    return if product.nil? || order.customer_user_id.nil? || requested.to_i <= 0

    demand = UnmetDemand.where(
      status:             "open",
      customer_user_id:   order.customer_user_id,
      product_id:         product.id,
      product_variant_id: product_variant&.id
    ).first_or_initialize

    demand.organisation_id ||= order.organisation_id
    demand.customer_id     ||= order.customer_id
    demand.first_seen_at   ||= Time.current
    # Decision 1a: keep the largest demand seen while open — don't sum across
    # repeated cart refreshes (that would inflate it every page view).
    demand.requested_quantity = [demand.requested_quantity.to_i, requested.to_i].max
    demand.reason             = reason.to_s
    demand.last_seen_at       = Time.current
    demand.save!

    demand.occurrences.create!(
      organisation_id:    order.organisation_id,
      customer_id:        order.customer_id,
      customer_user_id:   order.customer_user_id,
      product_id:         product.id,
      product_variant_id: product_variant&.id,
      requested_quantity: requested.to_i,
      kept_quantity:      kept.to_i,
      reason:             reason.to_s,
      occurred_at:        Time.current
    )

    demand
  rescue StandardError => e
    Rails.logger.warn("[UnmetDemand] record failed for order #{order&.id} product #{product&.id}: #{e.class}: #{e.message}")
    nil
  end

  def self.resolve_for_placed_order(order)
    return if order.customer_user_id.nil?

    order.order_items.each do |item|
      UnmetDemand.open
        .where(customer_user_id: order.customer_user_id, product_id: item.product_id)
        .where("product_variant_id IS NULL OR product_variant_id = ?", item.product_variant_id)
        .find_each { |demand| demand.register_fulfilment!(item.quantity) }
    end
  rescue StandardError => e
    Rails.logger.warn("[UnmetDemand] resolve failed for order #{order&.id}: #{e.class}: #{e.message}")
    nil
  end
end
