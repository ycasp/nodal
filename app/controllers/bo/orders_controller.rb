class Bo::OrdersController < Bo::BaseController
  before_action :set_order, only: [:show, :edit, :update, :destroy, :apply_discount, :remove_discount]

  def index
    @orders = policy_scope(current_organisation.orders.placed).includes(:customer, :order_items)

    # Search by order number or customer name
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @orders = @orders.joins(:customer).where(
        "orders.order_number ILIKE :search OR customers.company_name ILIKE :search OR customers.contact_name ILIKE :search",
        search: search_term
      )
    end

    # Filter by status
    @orders = @orders.where(status: params[:status]) if params[:status].present?

    # Filter by payment status
    @orders = @orders.where(payment_status: params[:payment_status]) if params[:payment_status].present?

    @orders = @orders.order(created_at: :desc)
  end

  def show
  end

  def edit
    @products = Product.where(organisation: @current_organisation)
  end

  def new
    @order = Order.new
    @customers = Customer.where(organisation: @current_organisation)
    @products = Product.where(organisation: @current_organisation)
    authorize @order
  end

  def create
    @order = Order.new(order_params)
    @order.organisation = @current_organisation
    @order.placed_at = Time.current
    authorize @order

    if @order.save
      redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id), notice: "Order created successfully."
    else
      @customers = Customer.where(organisation: @current_organisation)
      @products = Product.where(organisation: @current_organisation)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @order.update(order_params)
      redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id), notice: "Order updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @order.destroy
    redirect_to bo_orders_path(org_slug: @current_organisation.slug), notice: "Order deleted successfully."
  end

  def apply_discount
    if @order.update(order_discount_params.merge(applied_by: current_member))
      redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id),
                  notice: "Discount applied successfully."
    else
      redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id),
                  alert: "Failed to apply discount: #{@order.errors.full_messages.join(', ')}"
    end
  end

  def remove_discount
    @order.update(discount_type: nil, discount_value: nil, discount_reason: nil, applied_by: nil)
    redirect_to bo_order_path(org_slug: @current_organisation.slug, id: @order.id),
                notice: "Discount removed."
  end

  private

  def set_order
    @order = Order.find(params[:id])
    authorize @order
  end

  def order_params
    params.require(:order).permit(
      :customer_id, :status, :payment_status, :receive_on, :notes,
      order_items_attributes: [:id, :product_id, :quantity, :price, :discount_percentage, :_destroy]
    )
  end

  def order_discount_params
    params.require(:order).permit(:discount_type, :discount_value, :discount_reason)
  end
end
