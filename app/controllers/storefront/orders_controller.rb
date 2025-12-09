class Storefront::OrdersController < Storefront::BaseController
  def index
    @orders = policy_scope(current_customer.orders.placed, policy_scope_class: OrderPolicy::Scope)
                .includes(:order_items, :products)
                .order(placed_at: :desc)
  end

  def show
    @order = current_customer.orders.find(params[:id])
    authorize @order
  end

  def reorder
    original_order = current_customer.orders.placed.find(params[:id])
    authorize original_order

    # If cart has items and no confirmation, redirect back with warning
    if current_cart.order_items.any? && params[:confirm] != "true"
      flash[:warning] = "Your cart has items. Reordering will replace them."
      redirect_to order_path(org_slug: params[:org_slug], id: original_order, confirm_reorder: true)
      return
    end

    cart = current_cart
    skipped_items = []

    # Clear existing cart items
    cart.order_items.destroy_all

    original_order.order_items.includes(:product).each do |item|
      product = item.product

      if product.nil? || !product.active?
        skipped_items << item.product&.name || "Unknown product"
        next
      end

      cart.order_items.create!(
        product: product,
        quantity: item.quantity,
        discount_percentage: item.discount_percentage
      )
    end

    if skipped_items.any?
      flash[:warning] = "Some items were unavailable and skipped: #{skipped_items.join(', ')}"
    else
      flash[:notice] = "Items from order #{original_order.order_number} added to your cart."
    end

    redirect_to cart_path(org_slug: params[:org_slug])
  end
end
