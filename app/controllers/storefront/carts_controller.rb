class Storefront::CartsController < Storefront::BaseController
  def show
    @order = current_cart
    authorize @order, policy_class: OrderPolicy
    @order_items = @order.order_items.includes(product: :category)
  end

  def clear
    authorize current_cart, policy_class: OrderPolicy
    current_cart.order_items.destroy_all
    redirect_to cart_path(org_slug: params[:org_slug]), notice: "Cart cleared."
  end

  def place
    @order = current_cart
    authorize @order, policy_class: OrderPolicy

    if @order.order_items.any?
      @order.place!
      redirect_to order_path(org_slug: params[:org_slug], id: @order),
                  notice: "Order placed successfully!"
    else
      redirect_to cart_path(org_slug: params[:org_slug]),
                  alert: "Cannot place empty order."
    end
  end
end
