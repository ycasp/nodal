class StockRulesService
  def initialize(organisation)
    @organisation = organisation
  end

  def apply_to_variant(variant)
    record_stock_event(variant)

    # A variant that doesn't track stock is treated as unlimited / always in stock,
    # so it must stay available regardless of the org's out-of-stock strategy.
    # (Previously this returned early, leaving `available` stuck at its stale value
    # and hiding non-tracked products under the 'hide' strategy.)
    unless variant.track_stock?
      variant.update_column(:available, true) unless variant.available
      recalculate_product_availability(variant.product)
      return
    end

    policy = variant.effective_stock_policy
    # track_only: stock doesn't affect availability
    if policy == 'track_only'
      variant.update_column(:available, true) unless variant.available
    else
      # show_badge or hide: available reflects actual stock
      new_available = variant.stock_quantity.to_i > 0
      variant.update_column(:available, new_available) if variant.available != new_available
    end

    recalculate_product_availability(variant.product)
  end

  def recalculate_product_availability(product)
    variants = product.product_variants
    # For variable products, exclude the base/default variant (not sold separately)
    variants = variants.where(is_default: false) if product.has_variants? && variants.where(is_default: false).exists?
    # A product is available if at least one variant is published AND has stock
    any_available = variants.where(published: true, available: true).exists?
    product.update_column(:available, any_available) if product.available != any_available
  end

  private

  # Appends a StockEvent when the variant's stock crossed a meaningful
  # threshold in the save that preceded this call. Every stock write in the app
  # (ERP sync, BO edit, imports) funnels through apply_to_variant right after
  # `save`, so `saved_change_to_stock_quantity` still holds the [from, to] pair.
  #
  # Deliberately silent when there is no saved change: RecalculateStockJob
  # sweeps every variant and must not manufacture events out of nothing.
  def record_stock_event(variant)
    return unless variant.track_stock?
    # A brand-new variant reads as [nil, 10] -> "back in stock", which it isn't.
    # Only transitions on an existing variant are events.
    return if variant.previously_new_record?
    return if variant.instance_variable_get(:@stock_event_recorded)

    change = variant.saved_change_to_stock_quantity
    return if change.blank?

    from, to = change
    kind = StockEvent.kind_for(
      from: from,
      to: to,
      low_stock_threshold: @organisation.low_stock_threshold
    )
    return if kind.nil?

    StockEvent.create!(
      organisation_id: variant.organisation_id,
      product_variant_id: variant.id,
      kind: kind,
      from_quantity: from,
      to_quantity: to,
      occurred_at: Time.current
    )
    # Guards against a caller invoking apply_to_variant twice for the same save
    # (saved_changes survives until the next save/reload).
    variant.instance_variable_set(:@stock_event_recorded, true)
  end
end
