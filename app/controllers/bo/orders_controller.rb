class Bo::OrdersController < Bo::BaseController
  before_action :set_order, only: [:show, :edit, :update, :destroy]

  def index
    @orders = policy_scope(Order)
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

  private

  def set_order
    @order = Order.find(params[:id])
    authorize @order
  end

  def order_params
    params.require(:order).permit(
      :customer_id, :status, :payment_status, :receive_on, :notes,
      order_items_attributes: [:id, :product_id, :quantity, :unit_price, :discount_amount, :_destroy]
    )
  end
end
