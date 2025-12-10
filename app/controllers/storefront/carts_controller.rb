class Storefront::CartsController < Storefront::BaseController
  def show
    @order = current_cart
    authorize @order, policy_class: OrderPolicy
    @order_items = @order.order_items.includes(product: :category)
    @order_discounts = active_order_discounts
  end

  def clear
    authorize current_cart, policy_class: OrderPolicy
    current_cart.order_items.destroy_all
    redirect_to cart_path(org_slug: params[:org_slug]), notice: "Cart cleared."
  end
end
