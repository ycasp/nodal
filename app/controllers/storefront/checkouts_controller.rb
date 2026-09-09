class Storefront::CheckoutsController < Storefront::BaseController
  before_action :refresh_cart_pricing, only: :show

  def show
    @order = current_cart
    authorize @order, :checkout?, policy_class: OrderPolicy

    if @order.order_items.empty?
      redirect_to cart_path(org_slug: params[:org_slug]), alert: t('storefront.carts.show.empty_cart')
      return
    end

    @order_items = @order.order_items.includes(product: :category)
    @shipping_addresses = current_customer.shipping_addresses
    @billing_address = current_customer.billing_address
    @earliest_delivery_date = current_organisation.earliest_delivery_date

    case current_organisation.cart_price_change_policy
    when "notify"
      flash.now[:notice] = t("storefront.checkouts.show.prices_updated") if cart_pricing_changed?
    when "confirm"
      @price_change_modal = @order.pricing_change_pending?
    end
  end

  def acknowledge_pricing
    @order = current_cart
    authorize @order, :checkout?, policy_class: OrderPolicy
    @order&.acknowledge_pricing_change!
    redirect_to checkout_path(org_slug: params[:org_slug])
  end

  def update
    @order = current_cart
    authorize @order, :checkout?, policy_class: OrderPolicy

    if @order.order_items.empty?
      redirect_to cart_path(org_slug: params[:org_slug]), alert: t('storefront.carts.show.empty_cart')
      return
    end

    begin
      @order.assign_attributes(order_params)
      handle_addresses
      @order.terms_accepted_at = Time.current if checkout_params[:terms_accepted] == "1"
      @order.confirmed_stock_warnings = checkout_params[:confirmed_stock_warnings]
      if impersonating?
        @order.placed_by = current_member
        @order.sales_rep = current_org_member if current_org_member&.is_sales_rep?
      else
        @order.placed_by = current_customer_user
      end
      @order.finalize_checkout!(same_as_billing: checkout_params[:same_as_billing] == "1")

      # Customer-facing confirmation email:
      # - Self-service: send to the CustomerUser that just placed the order.
      # - Impersonation: rep explicitly picks recipients on the checkout form
      #   (notify_customer_user_ids). If none chosen, no customer email goes out.
      if impersonating?
        recipient_ids = Array(params.dig(:order, :notify_customer_user_ids)).reject(&:blank?)
        if recipient_ids.any?
          current_customer.customer_users.where(id: recipient_ids).find_each do |cu|
            CustomerMailer.with(customer_user: cu, order: @order, placed_by_rep: current_member)
                          .confirm_order.deliver_later
          end
        end
      else
        CustomerMailer.with(customer_user: current_customer_user, order: @order).confirm_order.deliver_later
      end
      MemberMailer.with(customer: current_customer, order: @order).notificate_customer_order.deliver_later

      notice = impersonating? ? "Encomenda colocada em nome de #{current_customer.company_name}." : t('storefront.flash.order_placed')
      redirect_to order_path(org_slug: params[:org_slug], id: @order), notice: notice
    rescue ActiveRecord::RecordInvalid => e
      @order_items = @order.order_items.includes(product: :category)
      @shipping_addresses = current_customer.shipping_addresses
      @billing_address = current_customer.billing_address
      @earliest_delivery_date = current_organisation.earliest_delivery_date
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
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
    checkout_params.except(:same_as_billing, :new_shipping_address, :new_billing_address, :shipping_address_id, :billing_address_id, :terms_accepted, :confirmed_stock_warnings)
  end

  def checkout_params
    params.require(:order).permit(
      :delivery_method, :receive_on, :notes, :terms_accepted, :confirmed_stock_warnings,
      :shipping_address_id, :billing_address_id, :same_as_billing,
      new_shipping_address: [:street_name, :postal_code, :city, :country],
      new_billing_address: [:street_name, :postal_code, :city, :country]
    )
  end
end
