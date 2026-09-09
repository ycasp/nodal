module CartHelper
  # Returns a stock badge for a cart line, or nil when there's nothing to show.
  # Only the "warn" policies surface a badge: "allow" is silent by design, and
  # "remove"/"cap" already resolved the issue in Order#refresh_cart!.
  def cart_stock_badge(item)
    org = item.order.organisation

    case item.stock_status
    when :out_of_stock, :variant_unpublished
      return unless org.cart_stock_policy == "warn"
      content_tag(:span, t("storefront.carts.show.stock.out_of_stock"),
                  class: "badge bg-danger-subtle text-danger")
    when :qty_overflow
      return unless org.cart_qty_overflow_policy == "warn"
      available = item.product_variant.stock_quantity.to_i
      content_tag(:span, t("storefront.carts.show.stock.only_n_left", count: available),
                  class: "badge bg-warning-subtle text-warning")
    end
  end
end
