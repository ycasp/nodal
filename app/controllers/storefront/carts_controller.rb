class Storefront::CartsController < Storefront::BaseController
  before_action :require_customer!
  before_action :refresh_cart_pricing, only: :show

  def show
    @order = current_cart
    authorize @order, policy_class: OrderPolicy
    @order_items = @order.order_items.includes(product: :category)
    @order_discounts = active_order_discounts
    @suggested_products = load_suggested_products
    @min_quantity_shortfall_by_product_id =
      @order.combined_min_quantity_shortfalls.index_by { |s| s[:product].id }
    if helpers.show_prices?
      nudges = CartDiscountNudges.new(@order)
      @discount_nudges = nudges.opportunities
      @discount_unlocked = nudges.unlocked
      # The "add N units" action lives on the cart row next to its SKU. Per-line
      # discounts nudge a specific variant (index by variant); summed ones nudge
      # the whole product (index by product).
      targeted = @discount_nudges.select(&:add_product_id)
      @nudge_by_variant_id = targeted.select(&:add_variant_id).index_by(&:add_variant_id)
      @nudge_by_product_id = targeted.reject(&:add_variant_id).index_by(&:add_product_id)
    end

    if cart_pricing_changed? && current_organisation.cart_price_change_policy != "silent"
      flash.now[:notice] = t("storefront.carts.show.prices_updated")
    end
  end

  def clear
    authorize current_cart, policy_class: OrderPolicy
    current_cart.order_items.destroy_all
    redirect_to cart_path(org_slug: params[:org_slug]), notice: "Cart cleared."
  end

  private

  def load_suggested_products
    cart_product_ids = current_cart.order_items.pluck(:product_id)

    # Try new products first
    products = current_organisation.products
                 .where(published: true)
                 .where.not(id: cart_product_ids)
                 .includes(:categories)
                 .order(created_at: :desc)
                 .limit(8)

    # Fallback to frequent products if no new ones
    if products.empty?
      frequent_ids = OrderItem.joins(:order)
        .where(orders: { customer_id: current_customer.id, organisation_id: current_organisation.id })
        .where.not(orders: { placed_at: nil })
        .where.not(product_id: cart_product_ids)
        .group(:product_id)
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(8)
        .pluck(:product_id)

      products = current_organisation.products
                   .where(id: frequent_ids, published: true)
                   .includes(:categories)
      products = products.sort_by { |p| frequent_ids.index(p.id) || 0 }
    end

    products
  end
end
