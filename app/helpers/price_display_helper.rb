module PriceDisplayHelper
  # Canonical price formatting for the storefront. Unlike
  # humanized_money_with_symbol, this always shows two decimals (€85,00 not
  # €85), matching the live JS pricing (toFixed(2)) so amounts never read
  # inconsistently side by side.
  def money_amount(value)
    return value unless value.respond_to?(:format)
    value.format
  end

  def format_discount_percentage(decimal_percentage)
    "#{(decimal_percentage * 100).round(0)}%"
  end

  # Live-pricing payload for the bulk grid (grid add-to-cart mode). Always
  # returns the per-variant prices so the JS can keep a running total in the
  # add-to-cart button; when there's a conditional discount it also carries the
  # condition so rows flip (per_line) or a summed tracker runs. scope "none"
  # means no condition — locked == unlocked, total only.
  def grid_live_pricing(product, variants)
    return nil unless show_prices?

    cart = current_cart && CartDiscountContext.new(current_cart.order_items.includes(:product_variant, product: :categories).to_a)
    conditional = DiscountCalculator.new(product: product, customer: current_customer, for_display: true, variant: nil)
                                    .all_discounts.find { |d| d[:condition] }
    cond = conditional&.dig(:condition)
    summed = cond && cond[:scope] == :summed
    min_qty = product.quantity_input_min

    pricing = variants.each_with_object({}) do |v, hash|
      next unless v.unit_price_cents.to_i.positive?

      if conditional
        locked = DiscountCalculator.new(product: product, customer: current_customer, quantity: min_qty, for_display: false, variant: v, cart_context: cart).final_price
        unlocked = DiscountCalculator.new(product: product, customer: current_customer, quantity: min_qty, for_display: true, variant: v, cart_context: cart).final_price
      else
        # No condition: the honest price is both locked and unlocked.
        locked = unlocked = DiscountCalculator.new(product: product, customer: current_customer, quantity: min_qty, for_display: false, variant: v, cart_context: cart).final_price
      end
      hash[v.id] = {
        locked: locked.cents, unlocked: unlocked.cents, base: v.unit_price_cents,
        cart: conditional ? variant_cart_toward(cart, product, v, cond, summed, conditional[:source]) : 0
      }
    end

    {
      pricing: pricing,
      condition_type: cond ? cond[:type].to_s : "none",
      threshold: cond ? (cond[:type] == :amount ? cond[:amount].cents : cond[:quantity]) : 0,
      scope: cond ? cond[:scope].to_s : "none",
      cart_summed: summed ? variant_cart_toward(cart, product, nil, cond, true, conditional[:source]) : 0,
      discount_label: conditional ? (conditional[:discount_type] == "percentage" ? "-#{(conditional[:value] * 100).round}%" : "-#{Money.new((conditional[:value] * 100).to_i, current_organisation.currency).format}") : ""
    }
  end

  # Cart units/€ already counting toward a summed threshold, in the discount's
  # scope: the whole category for a category discount (mirrors the non-grid
  # cart_scope_quantity), otherwise the product's own total. Per-line uses the
  # variant's own cart line.
  def variant_cart_toward(cart, product, variant, cond, summed, source = nil)
    return 0 unless cart

    if summed
      if source&.category_id
        cond[:type] == :amount ? cart.category_amount_cents(source.category_id) : cart.category_quantity(source.category_id)
      else
        cond[:type] == :amount ? cart.product_amount_cents(product.id) : cart.product_quantity(product.id)
      end
    else
      cond[:type] == :amount ? cart.variant_amount_cents(variant.id) : cart.variant_quantity(variant.id)
    end
  end

  def show_prices?
    !current_customer_user&.hide_prices?
  end
end
