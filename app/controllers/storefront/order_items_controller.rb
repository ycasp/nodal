class Storefront::OrderItemsController < Storefront::BaseController
  def create
    @product = current_organisation.products.where(available: true).find(params[:product_id])
    @order = current_cart

    @order_item = @order.order_items.find_by(product: @product)

    if @order_item
      @order_item.quantity += order_item_params[:quantity].to_i
    else
      # OrderItem callback set_discount_from_product will use DiscountCalculator
      # to apply the effective discount from all sources (ProductDiscount,
      # CustomerDiscount, CustomerProductDiscount)
      @order_item = @order.order_items.build(order_item_params.merge(product: @product))
    end

    authorize @order_item

    if @order_item.save
      redirect_to products_path(org_slug: params[:org_slug]), notice: "Added to cart."
    else
      redirect_to product_path(org_slug: params[:org_slug], product_id: @product.id),
                    alert: @order_item.errors.full_messages.join(", ")
    end
  end

  def update
    @order_item = current_cart.order_items.find(params[:id])
    authorize @order_item

    if @order_item.update(order_item_params)
      redirect_to cart_path(org_slug: params[:org_slug]), notice: "Cart updated."
    else
      redirect_to cart_path(org_slug: params[:org_slug]),
                  alert: @order_item.errors.full_messages.join(", ")
    end
  end

  def destroy
    @order_item = current_cart.order_items.find(params[:id])
    authorize @order_item
    @order_item.destroy
    redirect_to cart_path(org_slug: params[:org_slug]), notice: "Item removed."
  end

  private

  def order_item_params
    params.require(:order_item).permit(:quantity)
  end
end
