class Storefront::CheckoutsController < Storefront::BaseController
  def show
    @order = current_cart
    authorize @order, policy_class: OrderPolicy

    if @order.order_items.empty?
      redirect_to cart_path(org_slug: params[:org_slug]), alert: "Your cart is empty."
      return
    end

    @order_items = @order.order_items.includes(product: :category)
  end

  def update
    @order = current_cart
    authorize @order, policy_class: OrderPolicy

    if @order.order_items.empty?
      redirect_to cart_path(org_slug: params[:org_slug]), alert: "Your cart is empty."
      return
    end

    # Update delivery method and calculate final amounts
    @order.delivery_method = checkout_params[:delivery_method]
    @order.tax_amount = @order.calculated_tax
    @order.shipping_amount = @order.calculated_shipping
    @order.place!

    redirect_to order_path(org_slug: params[:org_slug], id: @order),
                notice: "Order placed successfully!"
  end

  private

  def checkout_params
    params.require(:order).permit(:delivery_method)
  end
end
