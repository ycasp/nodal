class Storefront::CheckoutsController < Storefront::BaseController
  def show
    @order = current_cart
    authorize @order, :checkout?, policy_class: OrderPolicy

    if @order.order_items.empty?
      redirect_to cart_path(org_slug: params[:org_slug]), alert: "Your cart is empty."
      return
    end

    @order_items = @order.order_items.includes(product: :category)
    @shipping_addresses = current_customer.shipping_addresses
    @billing_address = current_customer.billing_address
  end

  def update
    @order = current_cart
    authorize @order, :checkout?, policy_class: OrderPolicy

    if @order.order_items.empty?
      redirect_to cart_path(org_slug: params[:org_slug]), alert: "Your cart is empty."
      return
    end

    @order.assign_attributes(order_params)
    handle_addresses
    @order.finalize_checkout!(same_as_shipping: checkout_params[:same_as_shipping] == "1")

    CustomerMailer.with(customer: current_customer, order: @order).confirm_order.deliver_later

    redirect_to order_path(org_slug: params[:org_slug], id: @order),
                notice: "Order placed successfully!"
  end

  private

  def handle_addresses
    # Handle shipping address
    if checkout_params[:shipping_address_id] == "new" && checkout_params[:new_shipping_address].present?
      address = current_customer.shipping_addresses.create!(
        checkout_params[:new_shipping_address].merge(address_type: "shipping")
      )
      @order.shipping_address = address
    elsif checkout_params[:shipping_address_id].present? && checkout_params[:shipping_address_id] != "new"
      @order.shipping_address_id = checkout_params[:shipping_address_id]
    end

    # Handle billing address
    if current_customer.billing_address.blank? && checkout_params[:new_billing_address].present?
      address = Address.create!(
        checkout_params[:new_billing_address].merge(
          addressable: current_customer,
          address_type: "billing"
        )
      )
      @order.billing_address = address
    elsif checkout_params[:billing_address_id].present?
      @order.billing_address_id = checkout_params[:billing_address_id]
    elsif current_customer.billing_address.present?
      @order.billing_address = current_customer.billing_address
    end
  end

  def order_params
    # Address IDs are handled separately in handle_addresses
    checkout_params.except(:same_as_shipping, :new_shipping_address, :new_billing_address, :shipping_address_id, :billing_address_id)
  end

  def checkout_params
    params.require(:order).permit(
      :delivery_method, :receive_on, :notes,
      :shipping_address_id, :billing_address_id, :same_as_shipping,
      new_shipping_address: [:street_name, :postal_code, :city, :country],
      new_billing_address: [:street_name, :postal_code, :city, :country]
    )
  end
end
